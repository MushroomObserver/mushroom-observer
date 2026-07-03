# frozen_string_literal: true

require "test_helper"

class InatImportJobTrackerTest < ActiveSupport::TestCase
  def test_elapsed_time
    import = inat_imports(:rolf_inat_import)
    # NOT find_or_create_by: the rolf_tracker fixture already has an
    # InatImportJobTracker for this import, whose created_at is frozen
    # at fixture-load time (real wall-clock, once per worker process)
    # rather than "just now" — asserting elapsed_time ~0 against it is
    # flaky. create! always gets a fresh row with a real created_at.
    tracker = InatImportJobTracker.create!(inat_import: import.id)

    assert_in_delta(0, tracker.elapsed_time, 1,
                    "elapsed_time should be ~0 at creation")

    travel_to(tracker.created_at + 5.seconds) do
      assert_in_delta(5, tracker.elapsed_time, 1,
                      "elapsed_time should reflect time since creation")
    end
  end

  def test_estimated_remaining_time_at_job_start
    import = inat_imports(:rolf_inat_import)
    import.update(avg_import_time: import.initial_avg_import_seconds)
    tracker = InatImportJobTracker.find_or_create_by(inat_import: import.id)

    expected = (import.importables * import.avg_import_time).ceil
    assert_equal(expected, tracker.estimated_remaining_time,
                 "estimated_remaining_time should be importables × " \
                 "avg_import_time at job start")
  end

  def test_estimated_remaining_time_updates_with_avg_import_time
    import = inat_imports(:rolf_inat_import)
    import.update(avg_import_time: 30, imported_count: 1)
    tracker = InatImportJobTracker.find_or_create_by(inat_import: import.id)

    remaining = import.importables - import.imported_count
    assert_equal((remaining * 30).ceil, tracker.estimated_remaining_time,
                 "estimated_remaining_time should use live avg_import_time")
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
    import.update(avg_import_time: 10,
                  imported_count: import.importables + 1)
    tracker = InatImportJobTracker.find_or_create_by(inat_import: import.id)

    assert_equal(0, tracker.estimated_remaining_time,
                 "estimated_remaining_time should not go negative " \
                 "when imported_count exceeds importables")
  end
end
