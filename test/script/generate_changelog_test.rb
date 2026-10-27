# frozen_string_literal: true

require("test_helper")
require(Rails.root.join("script/generate_changelog").to_s)

# ChangelogGenerator against a stubbed git and GitHub, writing to a
# CHANGELOG.md in a temporary directory.
class GenerateChangelogTest < UnitTestCase
  T1 = "deploy-2026-10-01-08-00"
  T2 = "deploy-2026-10-05-08-00"
  T3 = "deploy-2026-10-10-08-00"
  TAGS = [T3, T1, T2, "deploy-not-a-date"].freeze
  RANGES = {
    "#{T1}..#{T2}" => %w[aaa bbb],
    "#{T2}..#{T3}" => %w[ccc ddd eee],
    "#{T3}..origin/main" => %w[fff ggg]
  }.freeze
  # sha => PRs GitHub associates with the commit: [number, merge sha].
  ASSOCIATED = {
    "aaa" => [[11, "ccc"]], # a branch commit of PR 11
    "bbb" => [[12, "bbb"]], # a squash merge
    "ccc" => [[11, "ccc"]], # PR 11's merge commit
    "ddd" => [[13, "ddd"]], # the changelog PR
    "eee" => [], # a commit pushed with no PR
    "fff" => [[14, "fff"]],
    "ggg" => [[15, "ggg"]]
  }.freeze
  PULLS = {
    11 => { "title" => " Add  feature ",
            "author" => { "login" => "alice", "__typename" => "User" } },
    12 => { "title" => "Bump gem",
            "author" => { "login" => "dependabot", "__typename" => "Bot" } },
    13 => { "title" => "Changelog for `deploy-x`", "author" => nil }
  }.freeze
  T2_SECTION = <<~MD.freeze
    ## 2026-10-05 (#{T2})

    - Bump gem ([PR12](https://github.com/o/r/pull/12), @app/dependabot)
  MD
  T3_SECTION = <<~MD.freeze
    ## 2026-10-10 (#{T3})

    - Add feature ([PR11](https://github.com/o/r/pull/11), @alice)
  MD

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

  def test_dry_run_prints_the_latest_deploy_section
    out, err, written = in_changelog_dir do
      [*run_generator([]), File.exist?("CHANGELOG.md")]
    end

    assert_equal(T3_SECTION, out)
    assert_match("Dry run - nothing written. To apply: " \
                 "script/generate_changelog.rb --apply", err)
    assert_not(written)
  end

  def test_dry_run_for_a_tag_with_no_prs
    out, err = in_changelog_dir(ranges: { "#{T1}..#{T2}" => [] }) do
      run_generator(["--tag", T2])
    end

    assert_match("(no merged PRs -- asset-only or config deploy)", out)
    assert_match("script/generate_changelog.rb --tag #{T2} --apply", err)
  end

  def test_apply_inserts_sections_newest_first
    content = in_changelog_dir do
      run_generator(["--tag", T2, "--apply"])
      run_generator(["--tag", T3, "--apply"])
      File.read("CHANGELOG.md")
    end

    assert_equal("# Changelog\n\n#{T3_SECTION}\n#{T2_SECTION}", content)
  end

  def test_apply_appends_an_older_section_at_the_end
    content = in_changelog_dir do
      run_generator(["--tag", T3, "--apply"])
      run_generator(["--tag", T2, "--apply"])
      File.read("CHANGELOG.md")
    end

    assert_equal("# Changelog\n\n#{T3_SECTION}\n#{T2_SECTION}", content)
  end

  def test_apply_refuses_a_section_already_present_without_replace
    in_changelog_dir do
      File.write("CHANGELOG.md", "# Changelog\n\n#{T3_SECTION}")
      err = assert_aborts do
        ChangelogGenerator.new(["--tag", T3, "--apply"]).run
      end

      assert_match("already has a section for #{T3}", err)
    end
  end

  def test_replace_swaps_a_section_in_place
    stale = "## 2026-10-05 (#{T2})\n\n- Old line\n"
    content = in_changelog_dir do
      File.write("CHANGELOG.md", "# Changelog\n\n#{T3_SECTION}\n#{stale}")
      run_generator(["--tag", T2, "--replace", "--apply"])
      File.write("CHANGELOG.md",
                 File.read("CHANGELOG.md").sub("- Add feature", "- Old"))
      run_generator(["--tag", T3, "--replace", "--apply"])
      File.read("CHANGELOG.md")
    end

    assert_equal("# Changelog\n\n#{T3_SECTION}\n#{T2_SECTION}", content)
  end

  def test_since_backfills_each_later_deploy_skipping_present_ones
    content = nil
    _out, err = in_changelog_dir do
      File.write("CHANGELOG.md", "# Changelog\n\n#{T3_SECTION}")
      result = run_generator(["--since", T1, "--apply"])
      content = File.read("CHANGELOG.md")
      result
    end

    assert_equal("# Changelog\n\n#{T3_SECTION}\n#{T2_SECTION}", content)
    assert_match("[1/2] #{T2}", err)
    assert_match("skipped: already in CHANGELOG.md", err)
  end

  def test_since_dry_run_with_replace_prints_every_section
    out, err = in_changelog_dir do
      File.write("CHANGELOG.md", "# Changelog\n\n#{T3_SECTION}")
      run_generator(["--since", T1, "--replace"])
    end

    assert_equal("#{T2_SECTION}#{T3_SECTION}", out)
    assert_match("script/generate_changelog.rb --since #{T1} --replace " \
                 "--apply", err)
  end

  def test_pending_pulls_since_the_last_tag_minus_the_changelog_branch
    with_github do
      tag, pulls = ChangelogGenerator.new([]).
                   pending_pulls(exclude_branch: "branch-14")

      assert_equal(T3, tag)
      assert_equal([15], pulls.pluck("number"))
    end
  end

  def test_apply_pending_drops_an_undeployed_pending_section
    pending = "deploy-2026-10-27-08-00"
    stale = "## 2026-10-20 (deploy-2026-10-20-08-00)\n\n- Stale\n"
    content = in_changelog_dir do
      File.write("CHANGELOG.md", "# Changelog\n\n#{stale}\n#{T3_SECTION}")
      generator = ChangelogGenerator.new([])
      section = generator.pending_section(pending, [])
      generator.apply_pending(section, pending)
      File.read("CHANGELOG.md")
    end

    assert_equal("# Changelog\n\n## 2026-10-27 (#{pending})\n\n" \
                 "(no merged PRs -- asset-only or config deploy)\n\n" \
                 "#{T3_SECTION}", content)
  end

  def test_bad_arguments_abort
    [
      [["--bogus"], "Unknown argument: --bogus"],
      [["--tag"], "Usage:"],
      [["--since"], "Usage:"],
      [["--tag", T2, "--since", T1], "mutually exclusive"]
    ].each do |argv, message|
      err = assert_aborts { ChangelogGenerator.new(argv) }

      assert_match(message, err, argv.join(" "))
    end
  end

  def test_bad_ranges_abort
    [
      [["--tag", T1], "earliest deploy tag"],
      [["--tag", "deploy-nope"], "is not a deploy-* tag"],
      [["--since", T3], "No deploy tags after #{T3}"]
    ].each do |argv, message|
      err = in_changelog_dir do
        assert_aborts { ChangelogGenerator.new(argv).run }
      end

      assert_match(message, err, argv.join(" "))
    end
  end

  def test_no_deploy_tags_aborts
    with_github(tags: []) do
      err = assert_aborts { ChangelogGenerator.new([]).run }
      assert_match("No deploy-* tags found.", err)

      err = assert_aborts { ChangelogGenerator.new([]).pending_pulls }
      assert_match("No deploy-* tags found.", err)
    end
  end

  private

  def merged_prs(shas, associated: ASSOCIATED, requests: [])
    with_github(ranges: { "deploy-a..deploy-b" => shas },
                associated: associated, requests: requests) do
      ChangelogGenerator.new([]).send(:merged_prs, "deploy-a", "deploy-b")
    end
  end

  def run_generator(argv)
    capture_io { ChangelogGenerator.new(argv).run }
  end

  # The abort message, which capture_io would drop on SystemExit.
  def assert_aborts(&block)
    err = StringIO.new
    original = $stderr
    $stderr = err
    assert_raises(SystemExit, &block)
    err.string
  ensure
    $stderr = original
  end

  def in_changelog_dir(**, &block)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { with_github(**, &block) }
    end
  end

  def with_github(tags: TAGS, ranges: RANGES, associated: ASSOCIATED,
                  requests: [], &block)
    run = lambda do |*cmd, **|
      case cmd[0..1]
      when %w[git tag] then tags.map { |tag| "#{tag}\n" }.join
      when %w[git rev-list] then "#{ranges.fetch(cmd.last).join("\n")}\n"
      else graphql(cmd.last.delete_prefix("query="), associated, requests)
      end
    end
    GithubCLI.stub(:run, run, &block)
  end

  def graphql(query, associated, requests)
    requests << query
    JSON.generate(data: { repository: respond(query, associated) })
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
               "url" => "https://github.com/o/r/pull/#{number}",
               "labels" => { "nodes" => [{ "name" => "review: standard" }] })
  end
end
