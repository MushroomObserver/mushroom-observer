# frozen_string_literal: true

require("test_helper")

class DiscardStaleJobsJobTest < ActiveJob::TestCase
  def test_discarding_failed_jobs
    assert_difference(
      "SolidQueue::FailedExecution.count", -1,
      "Should remove 1 entry from FailedExecutions"
    ) do
      DiscardStaleJobsJob.perform_now
    end
  end

  def test_discarding_finished_jobs
    assert_difference(
      "SolidQueue::Job.finished.count", -1,
      "Should discard 1 stale finished Job"
    ) do
      DiscardStaleJobsJob.perform_now
    end
  end
end
