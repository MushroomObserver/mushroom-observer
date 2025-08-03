# frozen_string_literal: true

require("test_helper")

# test the helpers for InatImportJobTracker
class InatImportJobTrackersHelperTest < ActionView::TestCase
  def test_time_in_hours_minutes_seconds
    tracker = inat_import_job_trackers(:ollie_tracker)
    assert_equal("Done", tracker.status, "Test needs fixture that's Done")

    assert_equal("00:00:00", remaining_time_in_hours_minutes_seconds(tracker))
  end
end
