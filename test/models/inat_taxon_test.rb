# frozen_string_literal: true

require("test_helper")

# test encapsulated imported iNat observations
class InatTaxonTest < UnitTestCase
  def test_name_basic
    mock_inat_obs = mock_observation("somion_unicolor")
    inat_taxon = InatTaxon.new(mock_inat_obs.inat_taxon)

    assert_equal(inat_taxon.name, names(:somion_unicolor),
                 "Incorrect MO Name for iNat community id")

    last_id = mock_inat_obs.inat_identifications.last
    inat_taxon = InatTaxon.new(last_id[:taxon])

    assert_equal(inat_taxon.name, names(:somion_unicolor),
                 "Incorrect MO Name for iNat identification")
  end

  ########

  private

  def mock_observation(filename)
    mock_search = File.read("test/inat/#{filename}.txt")
    # InatObs.new(File.read("test/inat/#{filename}.txt"))
    InatObs.new(JSON.generate(JSON.parse(mock_search)["results"].first))
  end
end
