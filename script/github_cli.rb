# frozen_string_literal: true

require("open3")

# Runs a command for the release scripts, retrying when GitHub's API
# times out or is briefly unavailable. Large `gh pr list --search` pages
# intermittently come back 502/504 and succeed on the next try.
module GithubCLI
  RETRYABLE = /HTTP 50[234]\b/
  WAITS = [5, 15, 45].freeze

  module_function

  # The command's stdout; aborts with its stderr once retries run out or
  # on any other failure.
  def run(*cmd, waits: WAITS)
    attempts = 0
    loop do
      out, err, status = Open3.capture3(*cmd)
      return out if status.success?

      wait = waits[attempts]
      abort("`#{cmd.join(" ")}` failed:\n#{err}") unless
        wait && RETRYABLE.match?(err)

      warn("GitHub #{err[RETRYABLE]}; retrying in #{wait}s...")
      sleep(wait)
      attempts += 1
    end
  end
end
