# frozen_string_literal: true

require("test_helper")

# test MO extensions to Ruby's Hash class
class ImportedInatObsTest < UnitTestCase
  def test_minimal_obs
    obs =
      ImportedInatObs.new(File.read("test/fixtures/inat/one_obs_public.json"))

=begin
      # attributes to test
      t.date "when"
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
      t.decimal "lat", precision: 15, scale: 10
      t.decimal "long", precision: 15, scale: 10
      t.string "where", limit: 1024
      t.integer "alt"
      t.string "lifeform", limit: 1024
      t.string "text_name", limit: 100
      t.text "classification"
      t.boolean "gps_hidden", default: false, null: false
=end
  end
end
