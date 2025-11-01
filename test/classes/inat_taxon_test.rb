# frozen_string_literal: true

require("test_helper")

# test encapsulated imported iNat observations
class InatTaxonTest < UnitTestCase
  def test_name_basic
    mock_inat_obs = mock_observation("somion_unicolor")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(inat_taxon.name, names(:somion_unicolor),
                 "Incorrect MO Name for iNat community id")

    last_id = mock_inat_obs[:identifications].last
    inat_taxon = Inat::Taxon.new(last_id[:taxon])

    assert_equal(inat_taxon.name, names(:somion_unicolor),
                 "Incorrect MO Name for iNat identification")
  end

  def test_complex
    user = rolf
    x_campanella_group = Name.new(
      rank: "Group",
      text_name: "Xeromphalina campanella group",
      search_name: "Xeromphalina campanella group",
      display_name: "**__Xeromphalina campanella__** group",
      sort_name: "Xeromphalina campanella   group",
      citation: "\"??Mycologia?? 107(6): 1270\":" \
                "https://www.tandfonline.com/doi/full/10.3852/15-087 (2017)",
      user: user
    )
    x_campanella_group.save

    mock_inat_obs = mock_observation("xeromphalina_campanella_complex")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(x_campanella_group, inat_taxon.name,
                 "Incorrect MO Name for iNat community id")
  end

  def test_mo_homonyms
    # Prove that it rerurns first homonym
    skip("under construction") # see issue #2381
  end

  ########

  private

  def mock_observation(filename)
    mock_search = File.read("test/inat/#{filename}.txt")
    # Inat::Obs.new(File.read("test/inat/#{filename}.txt"))
    Inat::Obs.new(JSON.generate(JSON.parse(mock_search)["results"].first))
  end
end
