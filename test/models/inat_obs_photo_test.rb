# frozen_string_literal: true

require("test_helper")

# iNat obs_photo key/values
# {:id=>351481052,
#  :position=>0,
#  :uuid=>"6c223538-04d6-404c-8e84-b7d881dbe550",
#  :photo_id=>377332865,
#  :photo=>
#   {:id=>377332865,
#    :license_code=>"cc-by-nc",

# MO image attributes
#  datetime "created_at", precision: nil
#  datetime "updated_at", precision: nil
#  string "content_type", limit: 100
#  integer "user_id"
#  date "when"
#  text "notes"
#  string "copyright_holder", limit: 100
#  integer "license_id", default: 1, null: false
#  integer "num_views", default: 0, null: false
#  datetime "last_view", precision: nil
#  integer "width"
#  integer "height"
#  float "vote_cache"
#  boolean "ok_for_export", default: true, null: false
#  string "original_name", limit: 120, default: ""
#  boolean "transferred", default: false, null: false
#  boolean "gps_stripped", default: false, null: false
#  boolean "diagnostic", default: true, null: false

# test mapping iNat observation photo key/values to MO Image attributes
class InatObsPhotoTest < UnitTestCase
  #    :original_dimensions=>{:width=>2048, :height=>1534},
#    :url=>"https://inaturalist-open-data.s3.amazonaws.com/photos/377332865/square.jpeg",
#    :attribution=>"(c) Tim C., some rights reserved (CC BY-NC)",
#    :flags=>[],
#    :moderator_actions=>[],
#    :hidden=>false}}

  FOTO =
    { id: 351481052,
      position: 0,
      uuid: "6c223538-04d6-404c-8e84-b7d881dbe550",
      photo_id: 377332865,
      photo: {
        id: 377332865,
        license_code: "cc-by-nc",
        original_dimensions: { width: 2048, height: 1534 },
        url: "https://inaturalist-open-data.s3.amazonaws.com/photos/377332865/square.jpeg",
        attribution: "(c) Tim C., some rights reserved (CC BY-NC)",
        flags: [],
        moderator_actions: [],
        hidden: false
      } }.freeze

  def test_simple_photo
    obs_photo = InatObsPhoto.new(FOTO)

    expected_license =
      License.where(License[:form_name] =~ "ccbync").where(deprecated: false).
      order(id: :asc).last

    assert_equal("img/jpeg", obs_photo.content_type)
    assert_equal("(c) Tim C., some rights reserved (CC BY-NC)",
                 obs_photo.copyright_holder)
    assert_equal("iNat photo uuid 6c223538-04d6-404c-8e84-b7d881dbe550",
                 obs_photo.original_name)
    assert_equal("original dimensions: 2048 x 1534",
                 obs_photo.notes)
    assert_equal(expected_license.id,
                 obs_photo.license_id,
                 "Wrong license, expecting #{expected_license.display_name}")
    assert_equal("https://inaturalist-open-data.s3.amazonaws.com/photos/377332865/original.jpeg",
                 obs_photo.url)
  end
end
