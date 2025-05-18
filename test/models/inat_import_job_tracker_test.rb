# frozen_string_literal: true

require "test_helper"

class InatImportJobTrackerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
  def test_timings
    tracker = inat_import_job_trackers(:timings_tracker)
    inat_import = inat_imports(:timings_import)

    travel((inat_import.imported_count * 10).seconds)

    assert_equal("00:01:20", tracker.remaining_time)
  end
end
