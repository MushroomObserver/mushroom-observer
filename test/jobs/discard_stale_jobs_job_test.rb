# frozen_string_literal: true

require("test_helper")

class DiscardStaleJobsJobTest < ActiveJob::TestCase
  def test_discarding_finished_jobs
    assert_difference("SolidQueue::Job.finished.count", -1) do
      DiscardStaleJobsJob.perform_now
    end
  end
end
