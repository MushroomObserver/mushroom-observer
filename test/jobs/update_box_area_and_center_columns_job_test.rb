# frozen_string_literal: true

require("test_helper")

class UpdateBoxAreaAndCenterColumnsJobTest < ActiveJob::TestCase
  def test_update_box_area_and_center_columns
    # Check that we have some obs that need updating
    assert_not_empty(Observation.in_box_of_max_area.where(location_lat: nil))

    job = UpdateBoxAreaAndCenterColumnsJob.new
    job.perform

    assert_empty(Observation.in_box_of_max_area.where(location_lat: nil))
    # NOTE: All locations may already have a box_area, so probably nil before
    assert_empty(Location.where(box_area: nil))
  end

  def test_update_box_area_dry_run
    # Check that we have some obs that need updating
    assert_not_empty(Observation.in_box_of_max_area.where(location_lat: nil))

    job = UpdateBoxAreaAndCenterColumnsJob.new
    _loc_count, obs_count = job.perform(dry_run: true)

    # check it again and be sure it did NOT update the obs
    needs_update = Observation.in_box_of_max_area.where(location_lat: nil)
    assert_not_empty(needs_update)
    assert_equal(obs_count, needs_update.count)
  end

  # A nil box_area is a data anomaly (box_area is computed on save), so it
  # gets a single #alerts summary.
  def test_alerts_when_a_location_is_missing_box_area
    locations(:albion).update_column(:box_area, nil)

    alerts = capture_alerts do
      UpdateBoxAreaAndCenterColumnsJob.new.perform(dry_run: true)
    end

    assert_equal(1, alerts.size)
    assert_instance_of(JobAlert, alerts.first)
    assert_includes(alerts.first.message, "box_area")
  end

  def test_no_alert_when_all_locations_have_box_area
    assert_empty(Location.where(box_area: nil),
                 "precondition: fixtures have no nil box_area")

    alerts = capture_alerts do
      UpdateBoxAreaAndCenterColumnsJob.new.perform(dry_run: true)
    end

    assert_empty(alerts)
  end

  private

  def capture_alerts(&block)
    alerts = []
    ExceptionNotifier.stub(:notifiers, [:slack]) do
      ExceptionNotifier.stub(:notify_exception,
                             lambda { |exception, **_o|
                               alerts << exception
                             }, &block)
    end
    alerts
  end
end
