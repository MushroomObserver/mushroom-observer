# frozen_string_literal: true

require("test_helper")
require("open3")
require("stringio")
require(Rails.root.join("script/prerelease_deploy_time").to_s)

# Which deploy time script/prerelease.rb uses, and how it reports it.
class PrereleaseDeployTimeTest < UnitTestCase
  NOW = Time.utc(2026, 10, 25, 6, 30)
  PR = { "number" => 5540,
         "title" => "Changelog for `deploy-2026-10-24-12-00`" }.freeze

  def test_now_wins
    travel_to(NOW) do
      choice = PrereleaseDeployTime.new(now: true, pending_pr: PR)

      assert_equal(NOW, choice.time)
      assert_equal("deploy-2026-10-25-06-30", choice.tag)
      assert_equal("Deploy time: 2026-10-25 06:30 UTC (from --now)",
                   choice.report)
    end
  end

  def test_at_overrides_the_pr_time
    travel_to(NOW) do
      at = DeployTime.parse("08:00 tomorrow", local_zone: "Europe/London")
      choice = PrereleaseDeployTime.new(at: at, at_text: "08:00 tomorrow",
                                        pending_pr: PR)

      assert_equal("deploy-2026-10-26-08-00", choice.tag)
      assert_equal("Deploy time: 2026-10-26 08:00 UTC (from --at " \
                   "\"08:00 tomorrow\", Europe/London (local))", choice.report)
    end
  end

  # A re-run during the deploy window keeps the PR's time even though it
  # has passed.
  def test_the_open_pr_time_is_kept
    travel_to(NOW) do
      choice = PrereleaseDeployTime.new(pending_pr: PR, apply: true)

      assert_equal(Time.utc(2026, 10, 24, 12), choice.time)
      assert_equal("deploy-2026-10-24-12-00", choice.tag)
      assert_equal("Deploy time: 2026-10-24 12:00 UTC (from PR #5540) -- " \
                   "in the past\n#{PrereleaseDeployTime::RESET_HINT}",
                   choice.report)
    end
  end

  def test_a_dry_run_with_no_pr_has_no_time
    travel_to(NOW) do
      choice = PrereleaseDeployTime.new

      assert_nil(choice.time)
      assert_equal("deploy-2026-10-25-??-??", choice.tag)
      assert_match(/Deploy time: not set/, choice.report)
    end
  end

  def test_a_pr_title_without_a_tag_counts_as_no_time
    choice = PrereleaseDeployTime.new(pending_pr: { "number" => 1,
                                                    "title" => "Changelog" })

    assert_nil(choice.time)
  end

  def test_apply_with_no_pr_asks_until_the_time_parses
    with_stdin("banana\n2026-10-26 08:00 UTC\n", tty: true) do
      _out, err = capture_io do
        choice = PrereleaseDeployTime.new(apply: true)

        assert_equal("deploy-2026-10-26-08-00", choice.tag)
        assert_match(/from "2026-10-26 08:00 UTC", UTC\)/, choice.report)
      end

      assert_match(/didn't understand "banana"/, err)
      assert_equal(2, err.scan("Deploy time (").size)
    end
  end

  def test_an_empty_answer_aborts
    with_stdin("\n", tty: true) do
      assert_raises(SystemExit) do
        capture_io { PrereleaseDeployTime.new(apply: true) }
      end
    end
  end

  def test_apply_without_a_terminal_aborts
    with_stdin("", tty: false) do
      _out, err = capture_io do
        assert_raises(SystemExit) { PrereleaseDeployTime.new(apply: true) }
      end

      assert_match(/give --at TIME or --now/, err)
    end
  end

  def test_parse
    assert_nil(PrereleaseDeployTime.parse(nil) { flunk })
    assert_equal("bad", PrereleaseDeployTime.parse("banana") { "bad" })
    assert_equal(Time.utc(2026, 10, 26, 8),
                 PrereleaseDeployTime.parse("2026-10-26 8am UTC").time)
  end

  # prerelease.rb runs as plain Ruby, where ActiveSupport extensions that
  # RuboCop's Rails cops suggest (Time.zone, blank?) don't exist.
  def test_runs_without_rails
    script = <<~RUBY
      require("./script/prerelease_deploy_time")
      at = PrereleaseDeployTime.parse("tomorrow 8pm") { |e| abort(e) }
      puts(PrereleaseDeployTime.new(at: at, at_text: "tomorrow 8pm").report)
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, "-e", script,
                                      chdir: Rails.root.to_s)

    assert_predicate(status, :success?, err)
    assert_match(/\ADeploy time: \d{4}-\d{2}-\d{2} \d{2}:\d{2} UTC/, out)
  end

  private

  def with_stdin(text, tty:)
    input = StringIO.new(text)
    input.define_singleton_method(:tty?) { tty }
    old = $stdin
    $stdin = input
    yield
  ensure
    $stdin = old
  end
end
