# frozen_string_literal: true

require("test_helper")
require(Rails.root.join("script/github_cli").to_s)

# Retries for the release scripts' gh calls.
class GithubCLITest < UnitTestCase
  OK = Struct.new(:success?).new(true)
  FAILED = Struct.new(:success?).new(false)
  BAD_GATEWAY = "HTTP 502: 502 Bad Gateway (https://api.github.com/graphql)"

  def test_retries_a_gateway_error_then_succeeds
    responses = [["", BAD_GATEWAY, FAILED], ["[]", "", OK]]

    out = nil
    _stdout, err = capture_io do
      Open3.stub(:capture3, ->(*) { responses.shift }) do
        out = GithubCLI.run("gh", "pr", "list", waits: [0])
      end
    end

    assert_equal("[]", out)
    assert_match(/GitHub HTTP 502; retrying in 0s/, err)
  end

  def test_gives_up_when_the_waits_run_out
    calls = 0
    always = lambda do |*|
      calls += 1
      ["", "HTTP 504: 504 Gateway Timeout", FAILED]
    end

    _stdout, err = capture_io do
      Open3.stub(:capture3, always) do
        assert_raises(SystemExit) do
          GithubCLI.run("gh", "pr", "list", waits: [0, 0])
        end
      end
    end

    assert_equal(3, calls)
    assert_match(/`gh pr list` failed:\nHTTP 504/, err)
  end

  def test_does_not_retry_other_failures
    calls = 0
    denied = lambda do |*|
      calls += 1
      ["", "gh: not logged in", FAILED]
    end

    capture_io do
      Open3.stub(:capture3, denied) do
        assert_raises(SystemExit) { GithubCLI.run("gh", "pr", "list") }
      end
    end

    assert_equal(1, calls)
  end
end
