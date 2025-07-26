# frozen_string_literal: true

require("test_helper")

# test mapping of iNat observation photo key/values to MO Image attributes
class InatObservationImporterTest < UnitTestCase
  def test_canceled
    import = inat_imports(:ollie_inat_import)
    assert(import.canceled?, "Test needs a canceled InatImport fixture")
    user = import.user
    mock_inat_response = File.read("test/inat/calostoma_lutescens.txt")
    page = JSON.parse(mock_inat_response)

    importer = ::Inat::ObservationImporter.new(import, user)
    assert_no_difference(
      "Observation.count",
      "ObservationImporter should stop importing if the Import is canceled"
    ) do
      importer.import_page(page)
    end
  end
end
