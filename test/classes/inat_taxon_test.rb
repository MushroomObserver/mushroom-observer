# frozen_string_literal: true

require("test_helper")

# test encapsulated imported iNat observations
class InatTaxonTest < UnitTestCase
  include InatStubHelpers

  def test_maps_inat_species_to_mo_species
    mock_inat_obs = mock_observation("somion_unicolor")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(inat_taxon.name, names(:somion_unicolor),
                 "Incorrect MO Name for iNat observation")

    last_id = mock_inat_obs[:identifications].last
    inat_taxon = Inat::Taxon.new(last_id[:taxon])

    assert_equal(inat_taxon.name, names(:somion_unicolor),
                 "Incorrect MO Name for iNat suggested ID")
  end

  def test_full_name_string_for_species
    mock_inat_obs = mock_observation("calostoma_lutescens")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal("Calostoma lutescens", inat_taxon.full_name_string)
  end

  def test_maps_inat_name_to_approved_mo_name
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

  def test_maps_inat_name_to_non_sensu_mo_name
    names = Name.where(text_name: "Coprinus", rank: "Genus", deprecated: false)
    assert(names.any? { |name| name.author.start_with?("sensu ") },
           "Test needs a Name fixture matching >= 1 MO `sensu` Name ")
    assert(names.one? { |name| !name.author.start_with?("sensu ") },
           "Test needs a Name fixture matching exactly 1 MO non-sensu Name")

    mock_inat_obs = mock_observation("coprinus")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal(names(:coprinus), inat_taxon.name,
                 "Prefer non-sensu Name when mapping iNat id to MO Name")
  end

  def test_full_name_string_for_genus
    mock_inat_obs = mock_observation("evernia")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_equal("Evernia", inat_taxon.full_name_string)
  end

  def test_maps_inat_infrageneric_to_mo_infrageneric_scientific_name
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

    assert_equal(
      name, inat_taxon.name,
      "iNat obs infrageneric name should map to MO Name which includes genus"
    )
  end

  def test_full_name_string_for_infrageneric_name
    mock_inat_obs = mock_observation("distantes")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])
    # Infrageneric taxa require a genus lookup because iNat returns only
    # the epithet and rank, not the full name including genus.
    stub_genus_lookup(
      ancestor_ids: inat_taxon[:ancestor_ids].join(","),
      body: { results: [{ name: "Morchella" }] }
    )

    # full_name_string uses the raw iNat rank ("section", not "sect.")
    # The MO Name parser normalizes rank abbreviations during name creation
    assert_equal("Morchella section Distantes", inat_taxon.full_name_string)
  end

  def test_maps_inat_infrageneric_suggest_id_to_mo_scientific_name
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

    assert_equal(name, ident_taxon.name,
                 "iNat suggested infrageneric ID should map to " \
                 "MO Name which includes genus")
  end

  def test_maps_inat_infraspecific_to_mo_infraspecific_scientific_name
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

    assert_equal(
      name, inat_taxon.name,
      "iNat infraspecific name should map to MO Name which includes rank"
    )
  end

  def test_maps_inat_complex_to_existing_mo_group
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

  def test_full_name_string_for_complex
    mock_inat_obs = mock_observation("xeromphalina_campanella_complex")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    # full_name_string returns the base name; the builder appends " complex"
    # and sets rank: "Group" when calling post_name for complex taxa
    assert_equal("Xeromphalina campanella", inat_taxon.full_name_string)
  end

  def test_returns_nil_when_no_mo_match
    assert_not(Name.exists?(text_name: "Calostoma lutescens"),
               "Test needs iNat taxon without an MO matching Name")
    mock_inat_obs = mock_observation("calostoma_lutescens")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon])

    assert_nil(inat_taxon.name,
               "Inat::Taxon#name should return nil when no MO Name matches")
  end

  def mock_observation(filename)
    mock_search = File.read("test/inat/#{filename}.txt")
    # Inat::Obs.new(File.read("test/inat/#{filename}.txt"))
    Inat::Obs.new(JSON.generate(JSON.parse(mock_search)["results"].first))
  end
end
