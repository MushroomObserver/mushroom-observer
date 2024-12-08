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
    user = rolf
    homonym = "Somion unicolor"
    Name.create!(
      user: user,
      text_name: homonym,
      search_name: homonym,
      sort_name: homonym,
      display_name: "__#{homonym}__",
      author: "Fries",
      rank: "Species",
      deprecated: false,
      correct_spelling: nil,
      citation: "",
      notes: ""
    )
    mock_inat_obs = mock_observation("somion_unicolor")

    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(
      Name.unknown, inat_taxon.name,
      "InatTaxon.name for homonyms should be the unknown Name"
    )
  end

  ########

  private

  def mock_observation(filename)
    mock_search = File.read("test/inat/#{filename}.txt")
    # Inat::Obs.new(File.read("test/inat/#{filename}.txt"))
    Inat::Obs.new(JSON.generate(JSON.parse(mock_search)["results"].first))
  end
end
