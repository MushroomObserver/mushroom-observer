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

  def test_creates_mo_species_for_unmatched_inat_species
    user = users(:rolf)
    expected_text_name = "Calostoma lutescens"
    assert_not(Name.exists?(text_name: expected_text_name),
               "Test needs iNat taxon without an MO matching Name")
    mock_inat_obs = mock_observation("calostoma_lutescens")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon], users(:rolf))

    mo_name = inat_taxon.name # The call to `name` is what creates the MO Name

    assert_equal(
      [expected_text_name, "Species"],
      [mo_name.text_name, mo_name.rank],
      "Failed to create MO Species for unmatched iNat taxon"
    )
    assert_equal(
      user, mo_name.user,
      "Wrong user associated with MO Name created for unmatched iNat taxon"
    )
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

  def test_creates_mo_genus_for_unmatched_inat_genus
    user = users(:rolf)
    expected_text_name = "Evernia"
    assert_not(Name.exists?(text_name: expected_text_name),
               "Test needs iNat taxon without an MO matching Name")
    mock_inat_obs = mock_observation("evernia")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon], users(:rolf))

    mo_name = inat_taxon.name # The call to `name` is what creates the MO Name

    assert_equal(
      [expected_text_name, "Genus"],
      [mo_name.text_name, mo_name.rank],
      "Failed to create MO Genus for unmatched iNat taxon"
    )
    assert_equal(
      user, mo_name.user,
      "Wrong user associated with MO Name created for unmatched iNat taxon"
    )
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

  def test_creates_mo_infrageneric_name_for_unmatched_inat_infrageneric_name
    user = users(:rolf)
    expected_text_name = "Morchella sect. Distantes"
    assert_not(Name.exists?(text_name: expected_text_name),
               "Test needs iNat taxon without an MO matching Name")
    mock_inat_obs = mock_observation("distantes")

    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon], user)
    # Need to lookup the genus of infrageneric taxa because
    # the iNat API returns only epithet and rank, not the genus
    stub_genus_lookup(
      ancestor_ids: inat_taxon[:ancestor_ids].join(","),
      body: { results: [{ name: "Morchella" }] }
    )

    mo_name = inat_taxon.name # The call to `name` is what creates the MO Name

    assert_equal([expected_text_name, "Section"],
                 [mo_name.text_name, mo_name.rank],
                 "Failed to create MO Section for unmatched iNat taxon")
    assert_equal(
      user, mo_name.user,
      "Wrong user associated with MO Name created for unmatched iNat taxon"
    )
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

  def test_creates_mo_complex_with_rank_group_for_unmatched_inat_complex
    user = users(:rolf)
    expected_text_name = "Xeromphalina campanella complex"
    assert_not(Name.exists?(text_name: expected_text_name),
               "Test needs iNat taxon without an MO matching Name")
    mock_inat_obs = mock_observation("xeromphalina_campanella_complex")
    inat_taxon = Inat::Taxon.new(mock_inat_obs[:taxon], users(:rolf))

    mo_name = inat_taxon.name # The call to `name` is what creates the MO Name

    assert_equal(
      [expected_text_name, "Group"],
      [mo_name.text_name, mo_name.rank],
      "Failed to create MO Group for unmatched iNat taxon"
    )
    assert_equal(
      user, mo_name.user,
      "Wrong user associated with MO Name created for unmatched iNat taxon"
    )
  end

  def mock_observation(filename)
    mock_search = File.read("test/inat/#{filename}.txt")
    # Inat::Obs.new(File.read("test/inat/#{filename}.txt"))
    Inat::Obs.new(JSON.generate(JSON.parse(mock_search)["results"].first))
  end
end
