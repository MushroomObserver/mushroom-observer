# frozen_string_literal: true

require("test_helper")

# test encapsulated imported iNat observations
class InatObsTest < UnitTestCase
  include Inat::Constants
  include InatStubHelpers

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
      lifeform: " ",

      # miscellaneous
      specimen: false,
      # notes: { Other: "on Quercus\n\n&#8212;\n\nMirrored on iNaturalist as <a href=\"https://www.inaturalist.org/observations/202555552\">observation 202555552</a> on March 15, 2024." }, # rubocop:disable Layout/LineLength
      notes: { Other: "on Quercus\n\n&#8212;\n\nOriginally posted to Mushroom Observer on Mar. 7, 2024." } # rubocop:disable Layout/LineLength
      # thumb_image_id: 1659475,
      # vote_cache: 2.51504,
      # num_views: 78,
      # last_view: Fri, 05 Apr 2024 15:59:58.000000000 EDT -04:00,
      # rss_log_id: 661676,
      # log_updated_at: Sat, 16 Mar 2024 17:22:51.000000000 EDT -04:00,
    )

    # mapping to MO Observation attributes, other than name attributes
    # Name attributes mappings are tested in InatTaxonTest
    %w[gps_hidden lat lng when where].
      each do |attribute|
        assert_equal(expected_mapping.send(attribute),
                     mock_inat_obs.send(attribute))
      end

    snapshot_subparts =
      <<~SNAPSHOT.gsub(/^\s+/, "").chomp
        #{mock_inat_obs.send(:copyright)}
        #{:USER.l}: #{mock_inat_obs[:user][:login]}
        #{:OBSERVED.l}: #{mock_inat_obs.when}
        #{:show_observation_inat_lat_lng.l}: #{mock_inat_obs.lat_lon_accuracy}
        #{:PLACE.l}: #{mock_inat_obs[:place_guess]}
        #{:ID.l}: #{mock_inat_obs.inat_taxon_name}
        #{:DQA.l}: #{mock_inat_obs.dqa}
        #{:show_observation_inat_suggested_ids.l}: #{mock_inat_obs.suggested_id_names}
        #{:OBSERVATION_FIELDS.t}: #{mock_inat_obs.obs_fields(mock_inat_obs.inat_obs_fields)}
      SNAPSHOT
    expected_snapshot = "\n#{snapshot_subparts}"
    assert_equal(expected_snapshot, mock_inat_obs.snapshot)

    # Observation form needs the Notes "parts" keys to be normalized
    snapshot_key = Observation.notes_normalized_key(:inat_snapshot_caption.l)
    other = "on Quercus\n\n" \
            "&#8212;\n\n" \
            "Originally posted to Mushroom Observer on Mar. 7, 2024."
    expected_notes = { snapshot_key => expected_snapshot,
                       Other: other }
    assert_equal(
      expected_notes, mock_inat_obs.notes,
      "MO notes should be the iNat snapshot && Description (collector " \
      "lives in the collector column, not notes)"
    )
    assert_equal("jdcohenesq", mock_inat_obs.collector,
                 "iNat collector should map to the collector column")

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

  def test_when
    fname = "somion_unicolor"
    mock_inat_obs = mock_observation(fname)
    assert_equal(Date.new(2023, 3, 23), mock_inat_obs.when)

    # create a mock_obs without an Observed on date
    # iNat allows this!
    mock_search = File.read("test/inat/#{fname}.txt")
    temp = JSON.parse(mock_search)["results"].first
    temp.keys.select { |k| k.start_with?("observed_on") }.
      each { |k| temp.delete(k) }
    mock_obs = Inat::Obs.new(JSON.generate(temp))
    assert_nil(mock_obs.when)
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
    assert_nil(
      mock_observation("somion_unicolor").
      inat_obs_field("Voucher Specimen Taken"),
      "iNat obs should not have a Voucher Specimen Taken observation field"
    )
  end

  # NOTE: iNat provisional names are not iNat taxa;
  # Rather, they simply string values of an observation field
  def test_provisional_name
    mock_inat_obs = mock_observation("arrhenia_sp_NY02")
    prov_name = mock_inat_obs.inat_prov_name
    assert(prov_name.present?)
    assert_equal('Arrhenia "sp-NY02"', prov_name)
    assert_equal('Arrhenia "sp-NY02"', mock_inat_obs.provisional_name,
                 "Provisional name should be unprocessed iNat provisional name")

    mock_inat_obs = mock_observation("donadinia_PNW01")
    prov_name = mock_inat_obs.inat_prov_name
    assert(prov_name.present?)
    assert_equal("Donadinia PNW01", prov_name)
    assert_equal("Donadinia PNW01", mock_inat_obs.provisional_name,
                 "Provisional name should be unprocessed iNat provisional name")

    mock_inat_obs = mock_observation("hygrocybe_sp_conica-CA06_ncbi_style")
    prov_name = mock_inat_obs.inat_prov_name
    assert(prov_name.present?)
    assert_equal("Hygrocybe sp. 'conica-CA06'", prov_name)
    assert_equal("Hygrocybe sp. 'conica-CA06'", mock_inat_obs.provisional_name,
                 "Provisional name should be unprocessed iNat provisional name")

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

  def test_name_override
    with_field = inat_obs_with_fields(
      [{ name: "Provisional Species Name", value: "ignore me" },
       { name: "Species Name Override", value: "Boletus edulis" }]
    )
    assert_equal("Boletus edulis", with_field.name_override)

    other_field = inat_obs_with_fields([{ name: "Other", value: "x" }])
    assert_nil(other_field.name_override)

    assert_nil(inat_obs_with_fields(nil).name_override)
  end

  def test_specimen
    assert_not(mock_observation("somion_unicolor").specimen?)
    # See comment in Inat::Obs#specimen? about disabling specimen detection
    # assert(mock_observation("arrhenia_sp_NY02").specimen?)
    assert_not(mock_observation("arrhenia_sp_NY02").specimen?)
  end

  def test_collector
    assert_equal(
      "Jasmine Silver & Jesse Burton",
      mock_observation("lycoperdon").collector,
      "Notes Collector should be iNat `Collector` field if that field present"
    )
    assert_equal(
      "johnplischke", mock_observation("arrhenia_sp_NY02").collector,
      "Notes Collector should be iNat user if no iNat Collector field"
    )
    assert_equal(
      "Michael Beug", mock_observation("russula_subabietis").collector,
      "Notes Collector should be iNat \"Collector's Name\" field " \
        "if that field present"
    )
  end

  def test_tags
    assert_equal(3, mock_observation("inocybe")[:tags].length)
    assert_empty(mock_observation("evernia")[:tags])
  end

  def test_dqa
    assert_equal(:inat_dqa_casual.l,
                 mock_observation("amanita_flavorubens").dqa)
    assert_equal(:inat_dqa_needs_id.l, mock_observation("coprinus").dqa)
    assert_equal(:inat_dqa_research.l, mock_observation("somion_unicolor").dqa)
  end

  def test_location_public
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

  def test_location_obscured
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

  def test_location_absent
    mock_inat_obs = mock_observation("no_location")
    assert_nil(
      mock_inat_obs.lat && mock_inat_obs.lng,
      "MO lat/lng should be nil for iNat observations without location"
    )
    assert_nil(
      mock_inat_obs.location,
      "MO obs.location should be undefined for iNat obss without location"
    )
  end

  def test_notes
    assert_equal("tyler_irvin", mock_observation("coprinus").collector,
                 "iNat collector should map to the collector column")
    assert_not(mock_observation("coprinus").notes.key?(:Collector),
               "collector should not live in notes")
    assert_equal(
      "Collection by Heidi Randall. \nSmells like T. suaveolens. ",
      strip_html_comments(mock_observation("trametes").notes[:Other]),
      "iNat Description should be mapped to MO Notes Other"
    )

    mock_obs = mock_observation("tremella_mesenterica")
    assert_equal(
      "", mock_obs.notes[:Other],
      "Notes Other should be a blank String if iNat Description is empty"
    )

    mock_obs = mock_observation("tremella_mesenterica")
    mock_obs[:description] = "before\r\n\r\n\r\n\r\nafter blank lines"
    assert_not(
      mock_obs.notes[:Other].match?(/\n{3,}/),
      "Failed to collapse multiple blank lines to a single blank line"
    )
    # Multiple blank lines collapse to a single blank line (no marker
    # since #4536).
    assert_equal(
      "before\n\nafter blank lines",
      mock_obs.notes[:Other],
      "Failed to collapse multiple blank lines to a single blank line"
    )
  end

  def strip_html_comments(str)
    str.gsub(/<!---.*?--->/m, "")
  end
  private :strip_html_comments

  # Re-imports of obs that previously had a MO back-link written into the
  # iNat description (legacy MO/Pulk's mirror script behavior) leak the
  # back-link line back into MO Notes. Strip those lines on import. (#4221)
  def test_notes_strip_mo_back_link_annotations
    mock_obs = mock_observation("tremella_mesenterica")
    mock_obs[:description] =
      "real iNat content\r\n\r\n" \
      "Imported by Mushroom Observer 2024-12-17\r\n" \
      "https://mushroomobserver.org/observations/568131\r\n" \
      "more iNat content"

    cleaned = strip_html_comments(mock_obs.notes[:Other])

    assert_not_includes(cleaned, "Imported by Mushroom Observer",
                        "Should strip 'Imported by Mushroom Observer' lines")
    assert_not_includes(cleaned, "mushroomobserver.org",
                        "Should strip MO back-link URL lines")
    assert_includes(cleaned, "real iNat content",
                    "Should preserve user-authored content above annotation")
    assert_includes(cleaned, "more iNat content",
                    "Should preserve user-authored content below annotation")
  end

  # The back-link strip must only match the canonical
  # "Imported by Mushroom Observer YYYY-MM-DD" annotation, not any user-
  # authored sentence that happens to start with that phrase.
  def test_notes_preserves_user_text_starting_with_back_link_phrase
    mock_obs = mock_observation("tremella_mesenterica")
    user_line = "Imported by Mushroom Observer? No, collected by hand."
    mock_obs[:description] = "before\r\n#{user_line}\r\nafter"

    cleaned = strip_html_comments(mock_obs.notes[:Other])

    assert_includes(cleaned, user_line,
                    "Should preserve user text that starts with the " \
                    "back-link phrase but isn't the canonical annotation")
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
    assert_not(
      mock_observation("euglena").taxon_importable?,
      "iNat non-mycetozoa protozoa observations should not be importable"
    )
  end

  def test_inat_obs_photos
    assert(mock_observation("amanita_flavorubens")[:observation_photos].none?)
    assert(mock_observation("coprinus")[:observation_photos].one?)
  end

  def test_copyright
    unlicensed_suffix =
      "#{OBS_COPYRIGHT_LABEL} Devin Welsh - #{ALL_RIGHTS_RESERVED}"

    # nil license_code: obs is unlicensed, no photos
    obs_no_license = mock_observation("amanita_flavorubens")
    assert_equal(
      unlicensed_suffix,
      obs_no_license.send(:copyright),
      "Unlicensed obs (nil license_code) should show 'all rights reserved'"
    )

    # "" license_code: obs is unlicensed but has >=1 licensed photo
    obs_empty_license = mock_observation("amanita_flavorubens")
    obs_empty_license[:license_code] = ""
    assert_equal(
      unlicensed_suffix,
      obs_empty_license.send(:copyright),
      "Unlicensed obs (empty string license_code) should show " \
      "'all rights reserved'"
    )

    # licensed obs
    obs_licensed = mock_observation("somion_unicolor")
    copyright = obs_licensed.send(:copyright)
    assert_match(
      %r{\A#{OBS_COPYRIGHT_LABEL} .+ \("cc-by-nc":https?://.+\)\z}o,
      copyright,
      "Licensed obs should include license code and URL"
    )
  end

  def test_suggested_id_names_links_unimportable_taxon_to_inat
    obs = mock_observation("ceanothus_cordulatus")
    ident_taxon = obs[:identifications].first[:taxon]
    expected_link =
      "\"_#{ident_taxon[:name]}_\":#{SITE}/taxa/#{ident_taxon[:id]}"

    assert_includes(obs.suggested_id_names, expected_link,
                    "Non-importable ident taxon should link to iNat taxa page")
  end

  def mock_observation(filename)
    mock_search = File.read("test/inat/#{filename}.txt")
    Inat::Obs.new(
      JSON.generate(JSON.parse(mock_search)["results"].first)
    )
  end

  # A minimal Inat::Obs with the given observation fields (ofvs), or none.
  def inat_obs_with_fields(ofvs)
    Inat::Obs.new(JSON.generate(
                    taxon: { name: "Boletus", rank: "species",
                             ancestor_ids: [] },
                    ofvs: ofvs
                  ))
  end
end
