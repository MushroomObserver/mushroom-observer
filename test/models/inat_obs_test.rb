# frozen_string_literal: true

require("test_helper")

# test encapsulated imported iNat observations
class InatObsTest < UnitTestCase
  # disable cop to facilitate typing/reading id's
  # rubocop:disable Style/NumericLiterals
  def test_complex_public_obs
    # import of iNat 202555552 which is a mirror of MO 547126)
    # For easier to to read version see test/inat/somion_unicolor.json
    mock_inat_obs = mock("somion_unicolor")

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
      # FIXME: add new source
      source: nil,
      # thumb_image_id: 1659475,
      # vote_cache: 2.51504,
      # num_views: 78,
      # last_view: Fri, 05 Apr 2024 15:59:58.000000000 EDT -04:00,
      # rss_log_id: 661676,
      # log_updated_at: Sat, 16 Mar 2024 17:22:51.000000000 EDT -04:00,
    )

    # mappings to Observation attributes
    %w[gps_hidden lat lng name_id notes text_name when where].
      each do |attribute|
        assert_equal(expected_mapping.send(attribute),
                     mock_inat_obs.send(attribute))
      end

    # TODO: include in above array after creating Observation.inat_id attribute

    expect = License.where(License[:url] =~ "/by-nc/").
             where(deprecated: false).order(id: :asc).first
    assert_equal(expect, mock_inat_obs.license)

=begin
      # other Observation attribute mappings to test
      t.integer "user_id"
      t.boolean "specimen", default: false, null: false
      t.integer "thumb_image_id"
      t.integer "location_id"
      t.boolean "is_collection_location", default: true, null: false
      t.integer "alt"
      t.string "lifeform", limit: 1024
      t.string "text_name", limit: 100
      t.text "classification"
      t.boolean "gps_hidden", default: false, null: false
=end

    # iNat attributes
    # NOTE: jdc 2024-06-13
    # Might seem circular, but need to insure it works with different iNat APIs
    assert_equal(202555552, mock_inat_obs.inat_id)
    assert_equal("31.8813,-109.244", mock_inat_obs.inat_location)
    assert_equal("Cochise Co., Arizona, USA", mock_inat_obs.inat_place_guess)
    assert_equal(20, mock_inat_obs.inat_public_positional_accuracy)
    assert_equal("research", mock_inat_obs.inat_quality_grade)
    assert_equal("Somion unicolor", mock_inat_obs.inat_taxon_name)
    assert_equal("jdcohenesq", mock_inat_obs.inat_user_login)
  end
  # rubocop:enable Style/NumericLiterals

  def test_name_sensu
    names = Name.where(text_name: "Coprinus", rank: "Genus")
    assert(names.any? { |name| name.author.start_with?("sensu ") } &&
           names.one? { |name| !name.author.start_with?("sensu ") },
           "Test needs a name matching >= 1 MO `send` Name " \
           "and exactly 1 MO non-sensu Name")

    mock_inat_obs = mock("coprinus")

    assert_equal(names(:coprinus).text_name, mock_inat_obs.text_name)
    assert_equal(names(:coprinus).id, mock_inat_obs.name_id)
  end

  # TODO: 2024-06-19 jdc. Add something w/o obs fields
  def test_inat_observation_fields
    assert(mock("trametes").inat_obs_fields.any?)
  end

  # TODO: 2024-06-19 jdc. Add something w/o tags
  def test_inat_tags
    assert(2, mock("inocybe").inat_tags.length)
  end

  def test_sequences
    mock_inat_obs = mock("lycoperdon")
    assert(mock_inat_obs.sequences.one?)
    sequence = mock_inat_obs.sequences.first
    assert(sequence.present?)

    assert_empty(mock("evernia_no_photos").sequences)
  end

  # TODO: 2024-06-19 jdc. Huh? method name? Add something with notes
  def test_no_description
    assert_equal("", mock("tremella_mesenterica").notes)
  end

  def test_taxon_importable
    # TODO: 2024-06-19 jdc. Fix this after fixing `importable?`
    assert(mock("somion_unicolor").taxon_importable?,
           "iNat Fungi observations should be importable")

    assert(mock("fuligo_septica").taxon_importable?,
           "iNat Slime mold (Protozoa) observations should be importable")

    assert_not(mock("ceanothus_cordulatus").taxon_importable?,
               "iNat Plant observations should not be importable")
  end

  # comma separated string of project names
  def test_inat_project_names
    assert_equal("??", mock("somion_unicolor").inat_project_names,
                 "wrong project names for iNat obs which lacks projects")

    assert_equal("Portland-Vancouver Regional Eco-Blitz, ??",
                 mock("evernia_no_photos").inat_project_names,
                 "wrong project names for iNat obs with 1 detectable project")

    # TODO: Test iNat obs with obs[:project_observations].many?
  end

  def mock(filename)
    InatObs.new(File.read("test/inat/#{filename}.txt"))
  end
end
