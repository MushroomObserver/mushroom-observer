# frozen_string_literal: true

require "test_helper"

class UpdateBoxAreaAndCenterColumnsJobTest < ActiveJob::TestCase
  def test_update_box_area_and_center_columns
    # Check that we have some obs that need updating
    assert_not_empty(Observation.in_box_of_max_area.where(location_lat: nil))

    job = UpdateBoxAreaAndCenterColumnsJob.new
    job.perform

    assert_empty(Observation.in_box_of_max_area.where(location_lat: nil))
    # Note: All locations should already have a box_area, so this was nil before
    assert_empty(Location.where(box_area: nil))
  end

  def test_update_box_area_dry_run
    # Check that we have some obs that need updating
    assert_not_empty(Observation.in_box_of_max_area.where(location_lat: nil))

    job = UpdateBoxAreaAndCenterColumnsJob.new
    _loc_count, obs_count = job.perform(dry_run: true)

    # check it again
    needs_update = Observation.in_box_of_max_area.where(location_lat: nil)
    assert_not_empty(needs_update)
    assert_equal(obs_count, needs_update.count)
  end
end
