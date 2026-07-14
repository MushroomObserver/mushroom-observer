# frozen_string_literal: true

require("test_helper")

class RefreshAllUserStatsJobTest < ActiveJob::TestCase
  # UserStats.refresh_all_user_stats already has its own dedicated test
  # coverage - this job's own contract is just that it calls that method,
  # forwards dry_run, and logs the result if there's anything to report.
  def test_perform_forwards_dry_run
    calls = []
    fake = lambda { |dry_run:|
      calls << dry_run
      []
    }

    UserStats.stub(:refresh_all_user_stats, fake) do
      RefreshAllUserStatsJob.perform_now(dry_run: true)
    end

    assert_equal([true], calls)
  end

  # Confirms the job actually integrates with the real model method (the
  # :dry_run kwarg name matches its real signature) - the stub-based test
  # above can't catch a signature mismatch since it fakes the call.
  def test_perform_runs_real_task_without_error
    RefreshAllUserStatsJob.perform_now(dry_run: true)
  end
end
