# frozen_string_literal: true

require("test_helper")
require(Rails.root.join("script/generate_changelog").to_s)

# How ChangelogGenerator finds the PRs merged in a deploy range: each
# commit asks GitHub which PR it was merged as. GitHub is stubbed.
class GenerateChangelogTest < UnitTestCase
  # sha => PRs GitHub associates with the commit: [number, merge sha].
  ASSOCIATED = {
    "aaa" => [[11, "zzz"]], # a branch commit of PR 11
    "bbb" => [[12, "bbb"]], # a squash merge
    "ccc" => [[11, "ccc"]], # PR 11's merge commit
    "ddd" => [[13, "ddd"]], # the changelog PR
    "eee" => [] # a commit pushed with no PR
  }.freeze
  PULLS = {
    11 => { "title" => "Feature", "author" => { "login" => "alice",
                                                "__typename" => "User" } },
    12 => { "title" => "Bump gem", "author" => { "login" => "dependabot",
                                                 "__typename" => "Bot" } },
    13 => { "title" => "Changelog for `deploy-x`", "author" => nil }
  }.freeze

  def test_finds_the_prs_merged_in_the_range_in_commit_order
    pulls = merged_prs(%w[aaa bbb ccc ddd eee])

    assert_equal([12, 11], pulls.pluck("number"),
                 "squash and merge commits, in order; branch commits, " \
                 "PR-less commits and the changelog PR left out")
    assert_equal("app/dependabot", pulls.first.dig("author", "login"),
                 "a bot author is shown the way gh shows it")
    assert_equal([{ "name" => "review: standard" }], pulls.first["labels"])
  end

  def test_splits_commits_and_prs_into_batches
    shas = Array.new(250) { |i| format("s%03d", i) }
    associated = shas.each_with_index.to_h do |sha, i|
      [sha, [[1000 + i, sha]]]
    end
    requests = []

    pulls = merged_prs(shas, associated: associated, requests: requests)

    assert_equal((1000...1250).to_a, pulls.pluck("number"))
    assert_equal(3, requests.count { |q| q.include?("associatedPullRequests") },
                 "100 commits per request")
    assert_equal(5, requests.count { |q| q.include?("pullRequest(number") },
                 "50 PRs per request")
  end

  private

  def merged_prs(shas, associated: ASSOCIATED, requests: [])
    run = lambda do |*cmd, **|
      next "#{shas.join("\n")}\n" if cmd.first == "git"

      query = cmd.last.delete_prefix("query=")
      requests << query
      JSON.generate(data: { repository: respond(query, associated) })
    end
    GithubCLI.stub(:run, run) do
      ChangelogGenerator.new([]).send(:merged_prs, "deploy-a", "deploy-b")
    end
  end

  def respond(query, associated)
    if query.include?("associatedPullRequests")
      query.scan(/(c\d+): object\(oid: "(\w+)"\)/).to_h do |key, sha|
        [key, commit(sha, associated[sha])]
      end
    else
      query.scan(/pr(\d+): pullRequest/).flatten.to_h do |n|
        ["pr#{n}", pull(n.to_i)]
      end
    end
  end

  def commit(sha, pulls)
    nodes = pulls.map do |number, merge|
      { number: number, mergeCommit: { oid: merge } }
    end
    { oid: sha, associatedPullRequests: { nodes: nodes } }
  end

  def pull(number)
    base = PULLS.fetch(number, { "title" => "PR #{number}",
                                 "author" => { "login" => "bob",
                                               "__typename" => "User" } })
    base.merge("number" => number, "headRefName" => "branch-#{number}",
               "labels" => { "nodes" => [{ "name" => "review: standard" }] })
  end
end
