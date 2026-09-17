# frozen_string_literal: true

# The PRs a deploy is shipping: merged since the most recent deploy tag
# reachable from HEAD, read from the git log and then fetched from
# GitHub's public API. Used on the production server, which has git but
# not the gh CLI.

require("json")
require("net/http")
require("open3")
require_relative("release_notes")

class DeployedPulls
  API = "https://api.github.com/repos/MushroomObserver/mushroom-observer/" \
        "pulls/%<number>d"

  # [pulls, problems]: pulls in the gh pr list JSON shape (number, title,
  # url, mergedAt, body); problems lists what couldn't be read, so a
  # caller can say its answer may be incomplete. The changelog PR is left
  # out.
  def self.fetch
    subjects, problem = git_subjects
    return [[], [problem]] if problem

    results = ReleaseNotes.pr_numbers(subjects).map { |number| pull(number) }
    pulls = results.filter_map { |pull, _| pull }.
            reject { |pull| pull["title"].to_s.start_with?("Changelog for ") }
    [pulls, results.filter_map { |_, error| error }]
  end

  # [subjects, problem] for commits since the previous deploy tag. A tag
  # on HEAD itself is this deploy's, so a re-run after tagging still
  # looks back to the one before.
  def self.git_subjects
    tag, _err, status = Open3.capture3(
      "git", "describe", "--tags", "--abbrev=0", "--match", "deploy-*",
      *head_deploy_tags.flat_map { |head_tag| ["--exclude", head_tag] }
    )
    return [[], "no deploy tag reachable from HEAD"] unless status.success?

    out, err, status = Open3.capture3("git", "log", "--format=%s",
                                      "#{tag.strip}..HEAD")
    return [[], "git log failed: #{err.strip}"] unless status.success?

    [out.lines.map(&:chomp), nil]
  end

  def self.head_deploy_tags
    out, _err, status = Open3.capture3("git", "tag", "--points-at", "HEAD",
                                       "--list", "deploy-*")
    status.success? ? out.split : []
  end

  # [pull, error], one of them nil.
  def self.pull(number)
    response = get(format(API, number: number))
    unless response.is_a?(Net::HTTPSuccess)
      return [nil, "PR ##{number}: HTTP #{response.code}"]
    end

    [gh_shape(JSON.parse(response.body)), nil]
  rescue StandardError => e
    [nil, "PR ##{number}: #{e.message}"]
  end

  def self.get(url)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5,
                                        read_timeout: 10) do |http|
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["User-Agent"] = "mushroom-observer-deploy"
      http.request(request)
    end
  end

  def self.gh_shape(json)
    { "number" => json["number"], "title" => json["title"],
      "url" => json["html_url"], "mergedAt" => json["merged_at"],
      "body" => json["body"] }
  end
end
