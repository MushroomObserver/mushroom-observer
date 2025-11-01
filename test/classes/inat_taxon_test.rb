# frozen_string_literal: true

require("test_helper")

# test encapsulated imported iNat observations
class InatTaxonTest < UnitTestCase
  include InatStubHelpers

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

  def test_name_sensu
    names = Name.where(text_name: "Coprinus", rank: "Genus", deprecated: false)
    assert(names.any? { |name| name.author.start_with?("sensu ") },
           "Test needs a Name fixture matching >= 1 MO `sensu` Name ")
    assert(names.one? { |name| !name.author.start_with?("sensu ") },
           "Test needs a Name fixture matching exactly 1 MO non-sensu Name")

    mock_inat_obs = mock_observation("coprinus")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(names(:coprinus), inat_taxon.name)
  end

  def test_infrageneric_name
    name = Name.create(
      user: rolf,
      rank: "Section",
      text_name: "Morchella sect. Distantes",
      search_name: "Morchella sect. Distantes Boud.",
      display_name: "**__Morchella__** sect. **__Distantes__** Boud.",
      sort_name: "Morchella  {2sect.  Distantes  Boud.",
      author: "Boud.",
      icn_id: 547_941
    )

    mock_inat_obs = mock_observation("distantes")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    ancestor_ids = inat_taxon[:ancestor_ids].join(",")
    stub_genus_lookup(
      ancestor_ids: ancestor_ids,
      body: { results: [{ name: "Morchella" }] }
    )

    assert_equal(name, inat_taxon.name)
  end

  def test_mo_homonyms
    skip("under construction")
  end

  ########

  private

  def mock_observation(filename)
    mock_search = File.read("test/inat/#{filename}.txt")
    # Inat::Obs.new(File.read("test/inat/#{filename}.txt"))
    Inat::Obs.new(JSON.generate(JSON.parse(mock_search)["results"].first))
  end
end
