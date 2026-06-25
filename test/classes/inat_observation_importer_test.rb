# frozen_string_literal: true

require("test_helper")

class InatObservationImporterTest < UnitTestCase
  # update_timings keeps a cumulative moving average (CMA) of per-observation
  # import time for the current job. After obs #1 with elapsed T: avg = T.
  # After obs #2 with elapsed S: avg = (T + S) / 2.
  def test_update_timings_cumulative_moving_average
    import = inat_imports(:rolf_inat_import)
    importer = ::Inat::ObservationImporter.new(import, import.user)

    # Simulate first obs taking ~10 seconds
    import.update(avg_import_time: 15.0, imported_count: 1,
                  last_obs_start: 10.seconds.ago)
    importer.send(:update_timings)
    import.reload
    assert_in_delta(10, import.avg_import_time, 1,
                    "After first obs, avg_import_time should equal elapsed " \
                    "time (CMA with count=1 collapses to the raw value)")

    # Simulate second obs taking ~20 seconds; mean of [10, 20] = 15
    import.update(imported_count: 2, last_obs_start: 20.seconds.ago)
    importer.send(:update_timings)
    import.reload
    assert_in_delta(15, import.avg_import_time, 1,
                    "After second obs, avg_import_time should be the mean " \
                    "of both elapsed times")
  end

  def test_canceled
    import = inat_imports(:ollie_inat_import)
    assert(import.canceled?, "Test needs a canceled InatImport fixture")
    user = import.user
    mock_inat_response = File.read("test/inat/calostoma_lutescens.txt")
    page = JSON.parse(mock_inat_response)

    importer = ::Inat::ObservationImporter.new(import, user)
    assert_no_difference(
      "Observation.count",
      "ObservationImporter should stop importing observations after " \
      "user cancels the Import"
    ) do
      importer.import_page(page)
    end
  end
end
