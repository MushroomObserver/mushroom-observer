# frozen_string_literal: true

require "test_helper"

class InatImportJobTrackerTest < ActiveSupport::TestCase
  def test_elapsed_and_remaining_time
    import = inat_imports(:rolf_inat_import)
    import.update(avg_import_time: import.initial_avg_import_seconds)
    tracker = InatImportJobTracker.find_or_create_by(inat_import: import.id)

    assert_in_delta(0, tracker.elapsed_time, 1,
                    "elapsed_time should be ~0 at creation")
    assert_in_delta(
      import.total_expected_time, tracker.estimated_remaining_time, 1,
      "estimated_remaining_time should equal total_expected_time at start"
    )

    travel_to(tracker.created_at + 5.seconds) do
      assert_in_delta(5, tracker.elapsed_time, 1,
                      "elapsed_time should reflect time since creation")
      assert_in_delta(
        import.total_expected_time - 5, tracker.estimated_remaining_time, 1,
        "estimated_remaining_time should decrease as time elapses"
      )
    end
  end

  def test_estimated_remaining_time_nil_without_importables
    import = inat_imports(:rolf_inat_import)
    import.update(importables: 0)
    tracker = InatImportJobTracker.find_or_create_by(inat_import: import.id)

    assert_nil(tracker.estimated_remaining_time,
               "estimated_remaining_time should be nil when importables is 0")
  end

  def test_estimated_remaining_time_zero_when_done
    tracker = inat_import_job_trackers(:lone_wolf_tracker)

    assert_equal(0, tracker.estimated_remaining_time,
                 "estimated_remaining_time should be 0 when import is Done")
  end

  def test_estimated_remaining_time_floors_at_zero
    import = inat_imports(:rolf_inat_import)
    import.update(avg_import_time: import.initial_avg_import_seconds)
    tracker = InatImportJobTracker.find_or_create_by(inat_import: import.id)

    # Travel past the total expected time so elapsed > total_expected_time
    travel_to(tracker.created_at + import.total_expected_time + 60) do
      assert_equal(0, tracker.estimated_remaining_time,
                   "estimated_remaining_time should not go negative")
    end
  end
end
