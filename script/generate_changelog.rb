#!/usr/bin/env ruby
# frozen_string_literal: true

# rubocop:disable MO/NoLongCommentBlock
# Generates one CHANGELOG.md section per production deploy: a dated
# heading for a deploy-* tag with a flat list of every
# PR merged since the previous deploy tag. A PR belongs to a deploy
# when its merge commit is reachable from that deploy's tag but not
# from the previous one -- true for merge, squash and rebase merges
# alike, and for a stacked PR in the deploy where its parent landed.
# PR numbers, titles and authors come from GitHub's GraphQL API through
# the gh CLI (run it wherever gh is authenticated).
#
#   Dry run (default -- prints the section(s), writes nothing):
#     script/generate_changelog.rb              # most recent deploy tag
#     script/generate_changelog.rb --tag deploy-2026-08-18-15-03
#     script/generate_changelog.rb --since deploy-2026-08-01-10-00
#   Apply (inserts into CHANGELOG.md, newest first):
#     script/generate_changelog.rb [--tag TAG | --since TAG] --apply
#   Regenerate sections already present (after a generator change):
#     script/generate_changelog.rb --since TAG --replace --apply
#
# --since TAG backfills one section for every deploy after TAG (TAG is
# the baseline, not itself listed). Sections are applied one at a time,
# so a failure mid-run keeps what was already written, and a rerun
# skips sections already present unless --replace is given.
#
# These CLI modes are for backfills and regeneration. The live flow
# runs through script/prerelease.rb, which drives this class's
# pending API to build the next deploy's section before the deploy.
# rubocop:enable MO/NoLongCommentBlock

require("json")
require_relative("github_cli")

# Builds and inserts one deploy's CHANGELOG.md section.
class ChangelogGenerator
  CHANGELOG = "CHANGELOG.md"
  TAG_PATTERN = /\Adeploy-(\d{4}-\d{2}-\d{2})-\d{2}-\d{2}\z/
  USAGE = "Usage: script/generate_changelog.rb " \
          "[--tag DEPLOY_TAG | --since DEPLOY_TAG] [--replace] [--apply]"
  HEADER = <<~MD
    # Changelog
  MD
  # Commits per "which PR was this merged as" request, and PRs per
  # details request; both keep each GraphQL response small.
  COMMIT_BATCH = 100
  PULL_BATCH = 50
  PULL_FIELDS = "number title url body mergedAt headRefName " \
                "author { login __typename } mergeCommit { oid } " \
                "labels(first: 30) { nodes { name } }"

  def initialize(argv)
    @apply = false
    @replace = false
    @tag = nil
    @since = nil
    parse_args(argv)
  end

  def run
    tags = deploy_tags
    abort("No deploy-* tags found.") if tags.empty?
    @since ? run_since(tags) : run_single(tags)
  end

  # -- Pre-deploy (prerelease) API, driven by script/prerelease.rb --

  # PRs merged since the last deploy tag up to origin/main, in commit
  # order, minus the changelog PR's branch (the changelog PR is left
  # out of the section it creates). Returns [previous_tag, pulls].
  def pending_pulls(exclude_branch: nil)
    tags = deploy_tags
    abort("No deploy-* tags found.") if tags.empty?

    pulls = merged_prs(tags.last, "origin/main")
    pulls = pulls.reject { |pr| pr["headRefName"] == exclude_branch }
    [tags.last, pulls]
  end

  # The section for a tag the prerelease run minted; the tag itself is
  # created later, by the deploy that ships the section.
  def pending_section(tag, pulls)
    build_section(tag, pulls)
  end

  # Insert the pending section, first dropping any stale pending
  # section -- a heading whose tag was minted by an earlier run and
  # was not deployed (its tag does not exist in git).
  def apply_pending(section, tag)
    content = changelog_content
    existing = deploy_tags
    section_positions(content).map { |_pos, t| t }.
      reject { |t| existing.include?(t) || t == tag }.
      each { |t| content = drop_section(content, t) }
    File.write(CHANGELOG, insert_sorted(content, section, tag))
  end

  private

  # Remove a section: its heading through the line before the next
  # heading (or end of file).
  def drop_section(content, tag)
    positions = section_positions(content)
    i = positions.index { |_pos, t| t == tag }
    return content unless i

    start = positions[i][0]
    tail = positions[i + 1] ? content[positions[i + 1][0]..] : ""
    "#{content[0...start]}#{tail}"
  end

  def parse_args(argv)
    args = argv.dup
    parse_arg(args.shift, args) until args.empty?
    abort("--tag and --since are mutually exclusive.\n#{USAGE}") if
      @tag && @since
  end

  def parse_arg(arg, rest)
    case arg
    when "--apply" then @apply = true
    when "--replace" then @replace = true
    when "--tag" then @tag = rest.shift || abort(USAGE)
    when "--since" then @since = rest.shift || abort(USAGE)
    else abort("Unknown argument: #{arg}\n#{USAGE}")
    end
  end

  def run_single(tags)
    target = @tag || tags.last
    index = tag_index(tags, target)
    abort("#{target} is the earliest deploy tag; no range.") if index.zero?

    section = build_section(target, merged_prs(tags[index - 1], target))
    @apply ? apply(section, target) : puts(section)
    dry_run_notice unless @apply
  end

  def run_since(tags)
    index = tag_index(tags, @since)
    targets = tags[(index + 1)..]
    abort("No deploy tags after #{@since}.") if targets.empty?

    targets.each_with_index do |target, i|
      warn("[#{i + 1}/#{targets.size}] #{target}")
      generate(tags[index + i], target)
    end
    dry_run_notice unless @apply
  end

  def generate(prev_tag, target)
    if present?(target) && !@replace
      return warn("  skipped: already in #{CHANGELOG} (--replace to redo).")
    end

    section = build_section(target, merged_prs(prev_tag, target))
    @apply ? apply(section, target) : puts(section)
  end

  def tag_index(tags, tag)
    tags.index(tag) ||
      abort("#{tag} is not a deploy-* tag (git fetch --tags?).")
  end

  # Zero-padded date-stamped names, so name order is date order.
  def deploy_tags
    run_cmd("git", "tag", "-l", "deploy-*").split("\n").
      grep(TAG_PATTERN).sort
  end

  # PRs whose merge commit is in prev..target, in commit order. Each
  # commit in the range asks GitHub which PR it was merged as, which
  # covers merge, squash and rebase merges and stacked PRs alike; a
  # branch commit names its PR too, but isn't that PR's merge commit.
  # Changelog PRs are bookkeeping about this file and are left out of
  # every section (#5155), the same way the pre-release PR leaves
  # itself out of the section it creates.
  def merged_prs(prev_tag, target_tag)
    commits = run_cmd("git", "rev-list", "--reverse",
                      "#{prev_tag}..#{target_tag}").split("\n")
    numbers = commits.each_slice(COMMIT_BATCH).
              flat_map { |batch| numbers_merged_as(batch) }.uniq
    pulls_by_number(numbers).reject { |pull| changelog_pr?(pull) }
  end

  # Numbers of the PRs merged as these commits, in the commits' order.
  def numbers_merged_as(commits)
    fields = commits.each_with_index.map do |sha, i|
      "c#{i}: object(oid: \"#{sha}\") { ... on Commit { oid " \
        "associatedPullRequests(first: 5) { nodes { number " \
        "mergeCommit { oid } } } } }"
    end
    repository(fields).values.compact.flat_map do |commit|
      commit.dig("associatedPullRequests", "nodes").
        select { |pull| pull.dig("mergeCommit", "oid") == commit["oid"] }.
        map { |pull| pull["number"] }
    end
  end

  # Full details, in the order given, shaped like `gh pr list --json`.
  def pulls_by_number(numbers)
    numbers.each_slice(PULL_BATCH).flat_map do |batch|
      fields = batch.map do |n|
        "pr#{n}: pullRequest(number: #{n}) { #{PULL_FIELDS} }"
      end
      repository(fields).values.map { |pull| gh_shaped(pull) }
    end
  end

  # gh shows a bot author as "app/<login>"; CHANGELOG.md's existing
  # lines do too.
  def gh_shaped(pull)
    author = pull["author"]
    if author&.fetch("__typename") == "Bot"
      author = { "login" => "app/#{author["login"]}" }
    end
    pull.merge("labels" => pull.dig("labels", "nodes").to_a,
               "author" => author)
  end

  def repository(fields)
    query = "query($owner: String!, $name: String!) { repository(" \
            "owner: $owner, name: $name) { #{fields.join(" ")} } }"
    JSON.parse(
      run_cmd("gh", "api", "graphql", "-F", "owner={owner}",
              "-F", "name={repo}", "-f", "query=#{query}")
    ).dig("data", "repository")
  end

  def changelog_pr?(pull)
    pull["headRefName"] == "changelog-pending" ||
      pull["title"].to_s.start_with?("Changelog for ")
  end

  def build_section(tag, prs)
    lines = ["## #{tag[/\Adeploy-(\d{4}-\d{2}-\d{2})-/, 1]} (#{tag})", ""]
    lines += if prs.empty?
               ["(no merged PRs -- asset-only or config deploy)"]
             else
               prs.map { |info| pr_line(info) }
             end
    "#{lines.join("\n")}\n"
  end

  # Link text "PRNNNN", not "#NNNN": a file full of [#NNNN](url) links
  # makes Copilot code review fail on every PR in the repo, and GitHub
  # does not autolink a bare #NNNN in a rendered file.
  def pr_line(info)
    "- #{clean_title(info["title"])} " \
      "([PR#{info["number"]}](#{info["url"]}), " \
      "@#{info.dig("author", "login")})"
  end

  # PR titles occasionally carry stray whitespace -- a non-breaking
  # space after an em dash, a double space around a dash. Collapse any
  # run of whitespace (nbsp included) to one regular space so the
  # changelog stays greppable and diffs cleanly. Word choice and
  # punctuation are left as the author wrote them.
  def clean_title(title)
    title.to_s.gsub(/[[:space:]]+/, " ").strip
  end

  def dry_run_notice
    range = if @since then " --since #{@since}"
            elsif @tag then " --tag #{@tag}"
            end
    replace = " --replace" if @replace
    warn("Dry run - nothing written. To apply: " \
         "script/generate_changelog.rb#{range}#{replace} --apply")
  end

  def changelog_content
    File.exist?(CHANGELOG) ? File.read(CHANGELOG) : HEADER
  end

  def present?(tag)
    changelog_content.include?("(#{tag})")
  end

  def apply(section, tag)
    content = changelog_content
    if present?(tag)
      unless @replace
        abort("#{CHANGELOG} already has a section for #{tag} (--replace " \
              "to redo).")
      end
      File.write(CHANGELOG, replace_section(content, section, tag))
      warn("Replaced #{tag} section in #{CHANGELOG}.")
    else
      File.write(CHANGELOG, insert_sorted(content, section, tag))
      warn("Inserted #{tag} section into #{CHANGELOG}.")
    end
  end

  # Sections run newest first. Insert above the first existing section
  # older than this tag, so historical tags can be applied in any
  # order; a tag newer than everything lands right under the header,
  # and one older than everything appends at the end.
  def insert_sorted(content, section, tag)
    older = section_positions(content).find { |_pos, t| t < tag }
    if older
      "#{content[0...older[0]]}#{section}\n#{content[older[0]..]}"
    else
      "#{content.chomp}\n\n#{section}"
    end
  end

  # Swap the section for this tag, heading through the line before the
  # next heading (or end of file).
  def replace_section(content, section, tag)
    positions = section_positions(content)
    i = positions.index { |_pos, t| t == tag }
    start = positions[i][0]
    tail = positions[i + 1] ? content[positions[i + 1][0]..] : ""
    "#{content[0...start]}#{section}#{"\n#{tail}" unless tail.empty?}"
  end

  # [offset, deploy-tag] for each section heading, in file order.
  def section_positions(content)
    positions = []
    content.scan(/^## \d{4}-\d{2}-\d{2} \((deploy-[0-9-]+)\)/) do
      positions << [Regexp.last_match.begin(0), Regexp.last_match[1]]
    end
    positions
  end

  def run_cmd(*cmd) = GithubCLI.run(*cmd)
end

ChangelogGenerator.new(ARGV).run if $PROGRAM_NAME == __FILE__
