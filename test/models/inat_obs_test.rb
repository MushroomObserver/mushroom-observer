# frozen_string_literal: true

require("test_helper")

# test encapsulated imported iNat observations
class InatObsTest < UnitTestCase
  # disable cop to facilitate typing/reading id's
  # rubocop:disable Style/NumericLiterals
  def test_complicated_public_obs
    # import of iNat 202555552 which is a mirror of MO 547126)
    # For easier to to read version see test/inat/somion_unicolor.json
    mock_inat_obs = mock_observation("somion_unicolor")

    expected_mapping = Observation.new(
      # id: 547126,
      # user_id: 4468,
      # created_at: Thu, 07 Mar 2024 18:32:18.000000000 EST -05:00,
      # updated_at: Mon, 18 Mar 2024 18:12:05.000000000 EDT -04:00,
      when: "Thu, 23 Mar 2023",

      # locality / geoloc stuff
      is_collection_location: true,
      lat: 31.8813,
      lng: -109.244,
      alt: 1942,
      gps_hidden: false,
      where: "Cochise Co., Arizona, USA",
      # location_id needs work
      location_id: 20799,

      # taxonomy, nomenclature
      text_name: "Somion unicolor",
      needs_naming: false,
      # name_id needs work
      name_id: names(:somion_unicolor).id,
      classification: "Domain: _Eukarya_\r\nKingdom: _Fungi_\r\nPhylum: _Basidiomycota_\r\nClass: _Agaricomycetes_\r\nOrder: _Polyporales_\r\nFamily: _Cerrenaceae_\r\n", # rubocop:disable Layout/LineLength
      lifeform: " ",

      # miscellaneous
      specimen: false,
      # notes: { Other: "on Quercus\n\n&#8212;\n\nMirrored on iNaturalist as <a href=\"https://www.inaturalist.org/observations/202555552\">observation 202555552</a> on March 15, 2024." }, # rubocop:disable Layout/LineLength
      notes: { Other: "on Quercus\n\n&#8212;\n\nOriginally posted to Mushroom Observer on Mar. 7, 2024." }, # rubocop:disable Layout/LineLength
      source: "mo_inat_import"
      # thumb_image_id: 1659475,
      # vote_cache: 2.51504,
      # num_views: 78,
      # last_view: Fri, 05 Apr 2024 15:59:58.000000000 EDT -04:00,
      # rss_log_id: 661676,
      # log_updated_at: Sat, 16 Mar 2024 17:22:51.000000000 EDT -04:00,
    )

    # mapping to MO Observation attributes
    %w[gps_hidden lat lng name_id source text_name when where].
      each do |attribute|
        assert_equal(expected_mapping.send(attribute),
                     mock_inat_obs.send(attribute))
      end

    expected_notes =
      { Collector: "jdcohenesq",
        Other: "on Quercus\n\n&#8212;\n\nOriginally posted " \
               "to Mushroom Observer on Mar. 7, 2024." }

    assert_equal(
      expected_notes, mock_inat_obs.notes,
      "MO notes should include: iNat Collector || login, iNat Description"
    )
    expected_snapshot =
      <<~SNAPSHOT.gsub(/^\s+/, "")
        #{:USER.l}: #{mock_inat_obs[:user][:login]}\n
        #{:OBSERVED.l}: #{mock_inat_obs.when}\n
        #{:show_observation_inat_lat_lng.l}: #{mock_inat_obs.lat_lon_accuracy}\n
        #{:PLACE.l}: #{mock_inat_obs[:place_guess]}\n
        #{:ID.l}: #{mock_inat_obs.inat_taxon_name}\n
        #{:DQA.l}: #{mock_inat_obs.dqa}\n
        #{:show_observation_inat_suggested_ids.l}: #{mock_inat_obs.suggested_id_names}\n
        #{:OBSERVATION_FIELDS.t}: #{mock_inat_obs.obs_fields(mock_inat_obs.inat_obs_fields)}\n
        #{:PROJECTS.l}: #{:inat_not_imported.l}\n
        #{:ANNOTATIONS.l}: #{:inat_not_imported.l}\n
        #{:TAGS.l}: #{:inat_not_imported.l}\n
      SNAPSHOT
    assert_equal(expected_snapshot, mock_inat_obs.snapshot)

    expect = License.where(License[:url] =~ "/by-nc/").
             where(deprecated: false).order(id: :asc).first
    assert_equal(expect, mock_inat_obs.license)

    #       # other Observation attribute mappings to test
    #       t.integer "user_id"
    #       t.boolean "specimen", default: false, null: false
    #       t.integer "thumb_image_id"
    #       t.integer "location_id"
    #       t.boolean "is_collection_location", default: true, null: false
    #       t.integer "alt"
    #       t.string "lifeform", limit: 1024
    #       t.string "text_name", limit: 100
    #       t.text "classification"
    #       t.boolean "gps_hidden", default: false, null: false

    # iNat attributes
    # NOTE: jdc 2024-06-13
    # Might seem circular, but need to insure it works with different iNat APIs
    assert_equal(202555552, mock_inat_obs[:id])
    assert_equal("31.8813,-109.244", mock_inat_obs[:location])
    assert_equal("Cochise Co., Arizona, USA", mock_inat_obs[:place_guess])
    assert_equal(20, mock_inat_obs[:public_positional_accuracy])
    assert_equal("research", mock_inat_obs[:quality_grade])
    assert_equal("Somion unicolor", mock_inat_obs.inat_taxon_name)
    assert_equal("jdcohenesq", mock_inat_obs[:user][:login])
    # Inocutis dryophila suggested once
    # then Somion unicolor suggested twice
    assert_equal(3, mock_inat_obs[:identifications].size)
  end
  # rubocop:enable Style/NumericLiterals

  def test_name_sensu
    # Make sure fixtures still OK
    names = Name.where(text_name: "Coprinus", rank: "Genus", deprecated: false)
    assert(names.any? { |name| name.author.start_with?("sensu ") } &&
           names.one? { |name| !name.author.start_with?("sensu ") },
           "Test needs a Name fixture matching >= 1 MO `sensu` Name " \
           "and exactly 1 MO non-sensu Name")

    mock_inat_obs = mock_observation("coprinus")

    assert_equal(names(:coprinus).id, mock_inat_obs.name_id)
    assert_equal(names(:coprinus).text_name, mock_inat_obs.text_name)
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

    assert_equal(name.id, mock_inat_obs.name_id)
    assert_equal(name.text_name, mock_inat_obs.text_name)
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

    assert_equal(name.id, mock_inat_obs.name_id)
    assert_equal(name.text_name, mock_inat_obs.text_name)
  end

  def test_names_alternative_authors
    # Make sure fixtures still OK
    names = Name.where(text_name: "Lentinellus ursinus", rank: "Species",
                       deprecated: false)
    assert(names.many? { |name| !name.author.start_with?("sensu ") },
           "Test needs a name with many non-sensu matching fixtures")

    mock_inat_obs = mock_observation("lentinellus_ursinus")
    assert_equal(
      "Lentinellus ursinus", mock_inat_obs.text_name,
      "Any of multiple, correctly spelled, approved Names will do."
    )
  end

  def test_names_approved_vs_deprecated
    # Make sure fixtures still OK
    names = Name.unscoped.
              where(text_name: "Lentinellus ursinus", rank: "Species",
                    deprecated: false)
    assert(names.many? { |name| !name.author.start_with?("sensu ") },
           "Test needs a name with many non-sensu matching fixtures")
    first_name = names.first
    first_name.deprecated = true
    first_name.save

    mock_inat_obs = mock_observation("lentinellus_ursinus")
    assert_equal(names.second.id, mock_inat_obs.name_id,
                 "Prefer non-deprecated Name when mapping iNat id to MO Name")
  end

  def test_inat_observation_fields
    assert(mock_observation("trametes").inat_obs_fields.any?)
    assert(mock_observation("evernia").inat_obs_fields.none?)
  end

  def test_inat_observation_field
    assert(
      mock_observation("arrhenia_sp_NY02").
      inat_obs_field("Voucher Specimen Taken").present?,
      "Failed to find iNat observation field"
    )
    assert(
      mock_observation("somion_unicolor").
      inat_obs_field("Voucher Specimen Taken").nil?,
      "iNat obs should not have a Voucher Specimen Taken observation field"
    )
  end

  def test_provisional_name
    mock_inat_obs = mock_observation("arrhenia_sp_NY02")
    prov_name = mock_inat_obs.inat_prov_name
    assert(prov_name.present?)
    assert_equal('Arrhenia "sp-NY02"', prov_name)
    assert_equal('Arrhenia "sp-NY02"', mock_inat_obs.provisional_name)

    mock_inat_obs = mock_observation("donadinia_PNW01")
    prov_name = mock_inat_obs.inat_prov_name
    assert(prov_name.present?)
    assert_equal("Donadinia PNW01", prov_name)
    assert_equal('Donadinia "sp-PNW01"', mock_inat_obs.provisional_name)

    assert_blank(
      mock_observation("amanita_flavorubens").inat_prov_name,
      "inat_prov_name should be blank for obs without observation fields"
    )
    assert_blank(
      mock_observation("trametes").inat_prov_name,
      "inat_prov_name should be blank for obs with observation fields, " \
      "but no provisional name field"
    )
  end

  def test_specimen
    assert(mock_observation("arrhenia_sp_NY02").specimen?)
    assert_not(mock_observation("somion_unicolor").specimen?)
  end

  def test_collector
    assert_equal(
      "Jasmine Silver & Jesse Burton",
      mock_observation("lycoperdon").collector,
      "Notes Collector should be iNat Collector field if that field present"
    )
    assert_equal(
      "johnplischke", mock_observation("arrhenia_sp_NY02").collector,
      "Notes Collector should be iNat user if no iNat Collector field"
    )
  end

  def test_complex_without_mo_match
    mock_inat_obs = mock_observation("xeromphalina_campanella_complex")
    assert_equal("Xeromphalina campanella", mock_inat_obs.inat_taxon_name)
    assert_equal("complex", mock_inat_obs.inat_taxon_rank)
    assert_equal(
      Name.unknown.text_name, mock_inat_obs.text_name,
      "iNat complex without MO name match should map to the Unknown name"
    )
  end

  def test_complex_with_mo_match
    name = Name.create(
      text_name: "Xeromphalina campanella group",
      author: "",
      display_name: "**__Xeromphalina campanella__** group",
      rank: "Group",
      user: users(:rolf)
    )
    mock_inat_obs = mock_observation("xeromphalina_campanella_complex")
    assert_equal("Xeromphalina campanella", mock_inat_obs.inat_taxon_name)
    assert_equal("complex", mock_inat_obs.inat_taxon_rank)
    assert_equal(name.text_name, mock_inat_obs.text_name)
  end

  def test_tags
    assert(2, mock_observation("inocybe")[:tags].length)
    assert_empty(mock_observation("evernia")[:tags])
  end

  def test_dqa
    assert_equal(:inat_dqa_casual.l,
                 mock_observation("amanita_flavorubens").dqa)
    assert_equal(:inat_dqa_needs_id.l, mock_observation("coprinus").dqa)
    assert_equal(:inat_dqa_research.l, mock_observation("somion_unicolor").dqa)
  end

  def test_public_location
    loc = locations(:albion)
    all_bounding_boxes = Location.contains_box(**loc.bounding_box)
    phony_locs = Location.where(north: 90, south: -90,
                                west: -180, east: 180).
                 where.not(name: "Earth")
    bounding_boxes =
      all_bounding_boxes.where.not(id: phony_locs.select(:id))
    assert(bounding_boxes.many?,
           "Test needs a Location fixture with multiple true bounding boxes")

    # modify a mock_inat_obs instead of trying to create one from scratch
    mock_inat_obs = mock_observation("somion_unicolor")
    loc_center = "#{loc.south + ((loc.north - loc.south) / 2)}," \
          "#{loc.west + ((loc.east - loc.west) / 2)}"
    mock_inat_obs[:location] = loc_center

    assert_equal(loc, mock_inat_obs.location)

    # Simulate nil accuracy, which is the case for some iNat obss
    # e.g., https://www.inaturalist.org/observations/230672879
    mock_inat_obs[:positional_accuracy] = nil
    mock_inat_obs[:public_positional_accuracy] = nil

    assert_equal(loc, mock_inat_obs.location)
  end

  def test_obscured_location
    mock_inat_obs = mock_observation("distantes")

    Location.create(user: rolf,
                    name: "Unblurred Location",
                    north: mock_inat_obs.lat + 0.001,
                    south: mock_inat_obs.lat - 0.001,
                    east: mock_inat_obs.lng + 0.001,
                    west: mock_inat_obs.lng - 0.001)

    blurred_location =
      Location.create(
        user: rolf,
        name: "Blurred Location",
        north: mock_inat_obs.lat +
               mock_inat_obs.public_accuracy_in_degrees[:lat] / 2,
        south: mock_inat_obs.lat -
               mock_inat_obs.public_accuracy_in_degrees[:lat] / 2,
        east: mock_inat_obs.lng +
              mock_inat_obs.public_accuracy_in_degrees[:lng] / 2,
        west: mock_inat_obs.lng -
              mock_inat_obs.public_accuracy_in_degrees[:lng] / 2
      )

    Location.create(
      user: rolf,
      name: "Insufficiently Blurred Location",
      north: mock_inat_obs.lat +
             mock_inat_obs.public_accuracy_in_degrees[:lat] - 0.001,
      south: mock_inat_obs.lat -
             mock_inat_obs.public_accuracy_in_degrees[:lat] + 0.001,
      east: mock_inat_obs.lng +
            mock_inat_obs.public_accuracy_in_degrees[:lng] - 0.001,
      west: mock_inat_obs.lng -
            mock_inat_obs.public_accuracy_in_degrees[:lng] + 0.001
    )

    assert_equal(
      [44.4659, -121.6967], [mock_inat_obs.lat, mock_inat_obs.lng],
      "Failed to import or use private lat/lng of obscured observation"
    )
    assert(mock_inat_obs.gps_hidden,
           "Obscured observation should have its gps hidden")
    assert_equal(
      blurred_location, mock_inat_obs.location,
      "Location should be blurred by at least Inat public_position_accuracy"
    )
  end

  def test_notes
    assert_equal({ Collector: "tyler_irvin" },
                 mock_observation("coprinus").notes,
                 "MO Notes should always include Collector:")
    assert_equal(
      "Collection by Heidi Randall. \nSmells like T. suaveolens. ",
      mock_observation("trametes").notes[:Other],
      "iNat Description should be mapped to MO Notes Other"
    )
  end

  def test_sequences
    mock_inat_obs = mock_observation("lycoperdon")
    assert(mock_inat_obs.sequences.one?)
    sequence = mock_inat_obs.sequences.first
    assert(sequence.present?)

    assert_empty(mock_observation("evernia").sequences)
  end

  def test_taxon_importable
    assert(mock_observation("somion_unicolor").taxon_importable?,
           "iNat Fungi observations should be importable")

    assert(mock_observation("fuligo_septica").taxon_importable?,
           "iNat Slime mold (Protozoa) observations should be importable")

    assert_not(mock_observation("ceanothus_cordulatus").taxon_importable?,
               "iNat Plant observations should not be importable")
  end

  def test_inat_obs_photos
    assert(mock_observation("amanita_flavorubens")[:observation_photos].none?)
    assert(mock_observation("coprinus")[:observation_photos].one?)
  end

  def mock_observation(filename)
    mock_search = File.read("test/inat/#{filename}.txt")
    Inat::Obs.new(JSON.generate(JSON.parse(mock_search)["results"].first))
  end
end
