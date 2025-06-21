# frozen_string_literal: true

require "test_helper"

class InatImportJobTrackerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
  def test_timings
    tracker = inat_import_job_trackers(:timings_tracker)
    inat_import = inat_imports(:timings_import)
    imported = inat_import.imported_count
    remaining = inat_import.importables - imported
    seconds_per_import = 10
    created = tracker.created_at

    travel_to(created + (imported * seconds_per_import).seconds) do
      assert_equal("00:00:#{imported * seconds_per_import}",
                   tracker.time_in_hours_minutes_seconds(tracker.elapsed_time))
      assert_equal("00:00:#{remaining * seconds_per_import}",
                   tracker.time_in_hours_minutes_seconds(
                     tracker.estimated_remaining_time
                   ))
    end
  end
end
