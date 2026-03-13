# frozen_string_literal: true

require "test_helper"

class InatImportJobTrackerTest < ActiveSupport::TestCase
  def test_elapsed_and_remaining_time
    import = inat_imports(:rolf_inat_import)
    import.update(avg_import_time: import.initial_avg_import_seconds)
    tracker = InatImportJobTracker.find_or_create_by(inat_import: import.id)

    assert_in_delta(0, tracker.elapsed_time, 1)
    assert_in_delta(import.total_expected_time,
                    tracker.estimated_remaining_time, 1)

    travel_to(tracker.created_at + 5.seconds) do
      assert_in_delta(5, tracker.elapsed_time, 1)
      assert_in_delta(import.total_expected_time - 5,
                      tracker.estimated_remaining_time, 1)
    end
  end
end
