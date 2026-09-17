# frozen_string_literal: true

require("test_helper")
require(Rails.root.join("script/deployed_pulls").to_s)

# PRs shipped by a deploy: git log since the previous deploy tag, then the
# GitHub API. git and HTTP are stubbed.
class DeployedPullsTest < UnitTestCase
  OK = Struct.new(:success?).new(true)
  FAILED = Struct.new(:success?).new(false)

  def test_fetch_reads_prs_since_the_previous_deploy_tag
    commands = []
    git = git_stub(commands, head_tags: "deploy-2026-09-17-12-00\n",
                             log: "Merge pull request #10 from x/a\n" \
                                  "A plain commit\n" \
                                  "Merge pull request #11 from x/changelog\n")
    responses = { 10 => pr_json(10, "Add maps"),
                  11 => pr_json(11, "Changelog for `deploy-x`") }

    pulls, problems = Open3.stub(:capture3, git) do
      DeployedPulls.stub(:get, ->(url) { response(responses, url) }) do
        DeployedPulls.fetch
      end
    end

    assert_equal([10], pulls.pluck("number"),
                 "the changelog PR is left out")
    assert_equal({ "number" => 10, "title" => "Add maps",
                   "url" => "https://github.com/pr/10",
                   "mergedAt" => "2026-09-17T10:00:00Z", "body" => "body" },
                 pulls.first)
    assert_empty(problems)
    assert_includes(commands.find { |cmd| cmd.include?("describe") },
                    "deploy-2026-09-17-12-00",
                    "this deploy's tag on HEAD is excluded")
  end

  def test_fetch_reports_unreadable_prs
    git = git_stub([], log: "Merge pull request #10 from x/a\n" \
                            "Fix it (#12)\n")
    get = lambda do |url|
      raise(SocketError.new("no route")) if url.end_with?("/12")

      Struct.new(:code).new("404")
    end

    pulls, problems = Open3.stub(:capture3, git) do
      DeployedPulls.stub(:get, get) { DeployedPulls.fetch }
    end

    assert_empty(pulls)
    assert_equal(["PR #10: HTTP 404", "PR #12: no route"], problems)
  end

  def test_fetch_without_a_deploy_tag
    git = lambda do |*cmd|
      cmd.include?("describe") ? ["", "no names", FAILED] : ["", "", OK]
    end

    assert_equal([[], ["no deploy tag reachable from HEAD"]],
                 Open3.stub(:capture3, git) { DeployedPulls.fetch })
  end

  def test_fetch_when_git_log_fails
    git = lambda do |*cmd|
      next ["", "bad range", FAILED] if cmd.include?("log")

      ["deploy-2026-09-15-12-00\n", "", OK]
    end

    assert_equal([[], ["git log failed: bad range"]],
                 Open3.stub(:capture3, git) { DeployedPulls.fetch })
  end

  def test_get_sends_the_github_headers
    seen = nil
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |request| seen = request }

    Net::HTTP.stub(:start, ->(*, **, &block) { block.call(fake_http) }) do
      DeployedPulls.get("https://api.github.com/repos/x/y/pulls/1")
    end

    assert_equal("application/vnd.github+json", seen["Accept"])
    assert_equal("mushroom-observer-deploy", seen["User-Agent"])
  end

  private

  def git_stub(commands, log:, head_tags: "")
    lambda do |*cmd|
      commands << cmd
      if cmd.include?("--points-at") then [head_tags, "", OK]
      elsif cmd.include?("describe") then ["deploy-2026-09-15-12-00\n", "", OK]
      else [log, "", OK]
      end
    end
  end

  def pr_json(number, title)
    { number: number, title: title,
      html_url: "https://github.com/pr/#{number}",
      merged_at: "2026-09-17T10:00:00Z", body: "body" }.to_json
  end

  def response(responses, url)
    body = responses.fetch(url[/\d+\z/].to_i)
    Net::HTTPOK.new("1.1", "200", "OK").tap do |ok|
      ok.instance_variable_set(:@read, true)
      ok.instance_variable_set(:@body, body)
    end
  end
end
