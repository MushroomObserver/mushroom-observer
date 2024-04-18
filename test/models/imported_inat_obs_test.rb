# frozen_string_literal: true

require("test_helper")

# test MO extensions to Ruby's Hash class
class ImportedInatObsTest < UnitTestCase
  def test_public_obs
    # import of iNat 202555552 (which is a mirror of MO 547126)
    import =
      ImportedInatObs.new(File.read("test/fixtures/inat/one_obs_public.txt"))
    # How import should be translated
    # commented-out fields will be part of the created MO Obs,
    # but are not supplied by
    expected_xlation = Observation.new(
      # id: 547126,
      # user_id: 4468,
      # created_at: Thu, 07 Mar 2024 18:32:18.000000000 EST -05:00,
      # updated_at: Mon, 18 Mar 2024 18:12:05.000000000 EDT -04:00,

      when: "Thu, 23 Mar 2023",

      # locality / geoloc stuff
      is_collection_location: true,
      lat: 31.8813, # rubocop:disable Style/ExponentialNotation
      lng: -109.244, # rubocop:disable Style/ExponentialNotation
      alt: 1942,
      gps_hidden: false,
      where: "Cochise Co., Arizona, USA",
      # location_id needs work
      location_id: 20799, # rubocop:disable Style/NumericLiterals

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
      source: nil
      # thumb_image_id: 1659475,
      # vote_cache: 2.51504,
      # num_views: 78,
      # last_view: Fri, 05 Apr 2024 15:59:58.000000000 EDT -04:00,
      # rss_log_id: 661676,
      # log_updated_at: Sat, 16 Mar 2024 17:22:51.000000000 EDT -04:00,
    )

    %w[gps_hidden lat lng name_id notes when where].each do |attribute|
      assert_equal(expected_xlation.send(attribute), import.send(attribute))
    end

=begin
      # attributes to test
      t.integer "user_id"
      t.boolean "specimen", default: false, null: false
      t.text "notes"
      t.integer "thumb_image_id"
      t.integer "name_id"
      t.integer "location_id"
      t.boolean "is_collection_location", default: true, null: false
      t.float "vote_cache", default: 0.0
      t.integer "num_views", default: 0, null: false
      t.datetime "last_view", precision: nil
      t.integer "rss_log_id"
      t.integer "alt"
      t.string "lifeform", limit: 1024
      t.string "text_name", limit: 100
      t.text "classification"
      t.boolean "gps_hidden", default: false, null: false
=end
  end
end
