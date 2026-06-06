# frozen_string_literal: true

require("test_helper")

# test the helpers for InatImportJobTracker
class InatImportJobTrackersHelperTest < ActionView::TestCase
  def test_time_in_hours_minutes_seconds
    tracker = inat_import_job_trackers(:ollie_tracker)
    assert_equal("Done", tracker.status, "Test needs fixture that's Done")

    assert_equal("00:00:00", remaining_time_in_hours_minutes_seconds(tracker))
  end

  def test_import_done_returns_true_when_state_is_done
    import = inat_imports(:ollie_inat_import)

    assert(import_done?(import),
           "Expected import_done? to be true for Done state")
  end

  def test_import_done_returns_false_when_state_is_not_done
    import = inat_imports(:katrina_inat_import)

    assert_not(import_done?(import),
               "Expected import_done? to be false for non-Done state")
  end

  def test_import_incomplete_returns_true_when_state_is_not_done
    import = inat_imports(:katrina_inat_import)

    assert(import_incomplete?(import),
           "Expected import_incomplete? to be true for Importing state")
  end

  def test_import_incomplete_returns_false_when_state_is_done
    import = inat_imports(:ollie_inat_import)

    assert_not(import_incomplete?(import),
               "Expected import_incomplete? to be false for Done state")
  end
end
