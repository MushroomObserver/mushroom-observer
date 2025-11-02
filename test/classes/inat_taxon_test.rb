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

  def test_names_approved_vs_deprecated
    # Make sure fixtures still OK
    names = Name.reorder(id: :asc).
            where(text_name: "Agrocybe arvalis", rank: "Species",
                  deprecated: false)
    assert(names.many? { |name| !name.author.start_with?("sensu ") },
           "Test needs a name with many non-sensu matching fixtures")
    first_name = names.first
    first_name.update(deprecated: true)

    mock_inat_obs = mock_observation("agrocybe_arvalis")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(names.second, inat_taxon.name,
                 "Prefer non-deprecated Name when mapping iNat id to MO Name")
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

  def test_infraspecific_name
    name = Name.create(
      user: rolf,
      rank: "Form",
      text_name: "Inonotus obliquus f. sterilis",
      search_name: "Inonotus obliquus f. sterilis (Vanin) Balandaykin & Zmitr.",
      display_name: "**__Inonotus obliquus__** f. **__sterilis__** " \
                    "(Vanin) Balandaykin & Zmitr.",
      sort_name: "Inonotus obliquus  {7f.  sterilis  " \
                 "(Vanin) Balandaykin & Zmitr.",
      author: "(Vanin) Balandaykin & Zmitr.",
      icn_id: 809_726
    )

    mock_inat_obs = mock_observation("i_obliquus_f_sterilis")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(name, inat_taxon.name)
  end

  def test_names_homonyms
    # Make sure fixtures still OK
    names = Name.where(text_name: "Agrocybe arvalis", rank: "Species",
                       deprecated: false)
    assert(names.many? { |name| !name.author.start_with?("sensu ") },
           "Test needs a name with many non-sensu matching fixtures")

    mock_inat_obs = mock_observation("agrocybe_arvalis")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(
      "Agrocybe arvalis", inat_taxon.name.text_name,
      "Any of multiple, correctly spelled, approved Names will do."
    )
  end

  def test_complex_with_mo_match
    name = Name.create(
      text_name: "Xeromphalina campanella group", author: "",
      search_name: "Xeromphalina campanella group",
      display_name: "**__Xeromphalina campanella__** group",
      rank: "Group",
      user: users(:rolf)
    )
    mock_inat_obs = mock_observation("xeromphalina_campanella_complex")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(name, inat_taxon.name,
                 "iNat `complex <Genus> <species>` should map to " \
                 "MO '<Genus> <species> group' if MO Name exists.")
  end

  def test_complex_without_mo_match
    mock_inat_obs = mock_observation("xeromphalina_campanella_complex")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(
      Name.unknown, inat_taxon.name,
      "iNat complex without MO name match should map to the Unknown name"
    )
  end

  def test_infrageneric_identification
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
    ident_taxon = Inat::Taxon.new(mock_inat_obs[:identifications].last[:taxon])
    ancestor_ids = ident_taxon[:ancestor_ids].join(",")
    stub_genus_lookup(
      ancestor_ids: ancestor_ids,
      body: { results: [{ name: "Morchella" }] }
    )

    assert_equal(name, ident_taxon.name)
  end

  def mock_observation(filename)
    mock_search = File.read("test/inat/#{filename}.txt")
    # Inat::Obs.new(File.read("test/inat/#{filename}.txt"))
    Inat::Obs.new(JSON.generate(JSON.parse(mock_search)["results"].first))
  end
end
