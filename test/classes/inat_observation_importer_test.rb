# frozen_string_literal: true

require("test_helper")

class InatObservationImporterTest < UnitTestCase
  def test_skip_inat_update_skips_update_inat_observation
    import = inat_imports(:rolf_inat_import)
    import.update!(skip_inat_update: true)
    user = import.user
    page = JSON.parse(File.read("test/inat/calostoma_lutescens.txt"))
    importer = ::Inat::ObservationImporter.new(import, user)

    # assert_not_requested checks WebMock's entire request history for the
    # process, not just this test. Resetting the executed-requests history
    # isolates this test from any other requests which ran earlier
    WebMock.reset_executed_requests!
    importer.import_page(page)

    assert_not_requested(:post, /observation_field_values/)
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
