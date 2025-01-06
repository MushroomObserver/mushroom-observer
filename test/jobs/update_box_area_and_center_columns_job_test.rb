require "test_helper"

class UpdateBoxAreaAndCenterColumnsJobTest < ActiveJob::TestCase
  def test_update_dry_run
    # ?
    # assert_difference("Observation.count", 1,
    #                   "Failed to create observation") do
    #   UpdateBoxAreaAndCenterColumnsJob.perform_now(dry_run: true)
    # end
  end
end
