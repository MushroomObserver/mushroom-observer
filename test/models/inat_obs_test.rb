# frozen_string_literal: true

require("test_helper")

# test encapsulated imported iNat observations
class InatObsTest < UnitTestCase
  # disable cop to facilitate typing/reading id's
  # rubocop:disable Style/NumericLiterals
  def test_complex_public_obs
    # import of iNat 202555552 which is a mirror of MO 547126)
    # For easier to to read version see test/fixtures/inat/somion_unicolor.json
    import =
      InatObs.new(File.read("test/fixtures/inat/somion_unicolor.txt"))

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
        assert_equal(expected_mapping.send(attribute), import.send(attribute))
      end

    # TODO: include in above array after creating Observation.inat_id attribute

    expect = License.where(License[:url] =~ "/by-nc/").
             where(deprecated: false).order(id: :asc).first
    assert_equal(expect, import.license)

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
    assert_equal(202555552, import.inat_id)
    assert_equal("31.8813,-109.244", import.inat_location)
    assert_equal("Cochise Co., Arizona, USA", import.inat_place_guess)
    assert_equal(20, import.inat_public_positional_accuracy)
    assert_equal("research", import.inat_quality_grade)
    assert_equal("Somion unicolor", import.inat_taxon_name)
    assert_equal("jdcohenesq", import.inat_user_login)
  end
  # rubocop:enable Style/NumericLiterals

  def test_name_sensu
    names = Name.where(text_name: "Coprinus", rank: "Genus")
    assert(names.any? { |name| name.author.start_with?("sensu ") } &&
           names.one? { |name| !name.author.start_with?("sensu ") },
           "Test needs a name matching >= 1 MO `send` Name " \
           "and exactly 1 MO non-sensu Name")

    import = InatObs.new(File.read("test/fixtures/inat/coprinus.txt"))

    assert_equal(names(:coprinus).text_name, import.text_name)
    assert_equal(names(:coprinus).id, import.name_id)
  end

  def test_inat_observation_fields
    import = InatObs.new(File.read("test/fixtures/inat/trametes.txt"))
    assert(import.inat_obs_fields.any?)
  end

  def test_inat_tags
    import = InatObs.new(File.read("test/fixtures/inat/inocybe.txt"))
    assert(2, import.inat_tags.length)
  end

  def test_no_description
    inat_response = File.read("test/fixtures/inat/tremella_mesenterica.txt")
    assert_match(/"description":null,/, inat_response,
                 "Need iNat observation lacking description")

    import = InatObs.new(inat_response)

    assert_equal("", import.notes)
  end

  def test_taxon_importable
    inat_obs =
      InatObs.new(File.read("test/fixtures/inat/somion_unicolor.txt"))
    assert(inat_obs.taxon_importable?,
           "iNat Fungi observations should be importable")

    inat_obs =
      InatObs.new(File.read("test/fixtures/inat/fuligo_septica.txt"))
    assert(inat_obs.taxon_importable?,
           "iNat Slime mold (Protozoa) observations should be importable")

    inat_obs =
      InatObs.new(
        File.read("test/fixtures/inat/ceanothus_cordulatus.txt")
      )
    assert_not(inat_obs.taxon_importable?,
               "iNat Plant observations should not be importable")
  end

  # comma separated string of project names
  def test_inat_project_names
    import =
      # has no projects
      InatObs.new(File.read("test/fixtures/inat/somion_unicolor.txt"))
    assert_equal("??", import.inat_project_names)

    import =
      # has one project
      InatObs.new(File.read("test/fixtures/inat/evernia_no_photos.txt"))
    assert_equal("Portland-Vancouver Regional Eco-Blitz, ??",
                 import.inat_project_names)

    # TODO: Test iNat obs with obs[:project_observations].many?
  end
end
