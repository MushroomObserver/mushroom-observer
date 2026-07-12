# frozen_string_literal: true

require("test_helper")

class RefreshContentFilterCachesJobTest < ActiveJob::TestCase
  # Observation.refresh_content_filter_caches already has its own dedicated
  # test coverage - this job's own contract is just that it calls that
  # method, forwards dry_run, and logs the result if there's anything to
  # report.
  def test_perform_forwards_dry_run
    calls = []
    fake = lambda { |dry_run:|
      calls << dry_run
      []
    }

    Observation.stub(:refresh_content_filter_caches, fake) do
      RefreshContentFilterCachesJob.perform_now(dry_run: true)
    end

    assert_equal([true], calls)
  end

  # Confirms the job actually integrates with the real model method (the
  # :dry_run kwarg name matches its real signature) - the stub-based test
  # above can't catch a signature mismatch since it fakes the call.
  def test_perform_runs_real_task_without_error
    RefreshContentFilterCachesJob.perform_now(dry_run: true)
  end
end
