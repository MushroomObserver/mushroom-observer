# frozen_string_literal: true

require("test_helper")

# iNat inat_obs_photo key/values
# {:id=>351481052,
#  :position=>0,
#  :uuid=>"6c223538-04d6-404c-8e84-b7d881dbe550",
#  :photo_id=>377332865,
#  :photo=>
#   {:id=>377332865,
#    :license_code=>"cc-by-nc",
#    :original_dimensions=>{:width=>2048, :height=>1534},
#    :url=>"https://inaturalist-open-data.s3.amazonaws.com/photos/377332865/square.jpeg",
#    :attribution=>"(c) Tim C., some rights reserved (CC BY-NC)",
#    :flags=>[],
#    :moderator_actions=>[],
#    :hidden=>false}}

# some MO image attributes
#  string "content_type", limit: 100
#  integer "user_id"
#  date "when"
#  text "notes"
#  string "copyright_holder", limit: 100
#  integer "license_id", default: 1, null: false
#  integer "width"
#  integer "height"
#  boolean "ok_for_export", default: true, null: false
#  string "original_name", limit: 120, default: ""
#  boolean "gps_stripped", default: false, null: false
#  boolean "diagnostic", default: true, null: false

# test mapping of iNat observation photo key/values to MO Image attributes
class InatObsPhotoTest < UnitTestCase
  def test_simple_photo
    inat_obs_data = InatObs.new(
      File.read("test/fixtures/inat/tremella_mesenterica.txt")
    )
    inat_obs_photo = InatObsPhoto.new(
      inat_obs_data.obs[:observation_photos].first
    )
    expected_license =
      License.where(License[:url] =~ "/by-nc/").where(deprecated: false).
      order(id: :asc).last

    assert_equal("img/jpeg", inat_obs_photo.content_type)
    assert_equal("(c) Tim C., some rights reserved (CC BY-NC)",
                 inat_obs_photo.copyright_holder)
    assert_equal("iNat photo uuid 6c223538-04d6-404c-8e84-b7d881dbe550",
                 inat_obs_photo.original_name)
    # assert_equal("original dimensions: 2048 x 1534",
    assert_equal(
      "Imported from iNat #{DateTime.now.utc.strftime("%Y-%m-%d %H:%M:%S %z")}",
      inat_obs_photo.notes
    )

    assert_equal(expected_license,
                 inat_obs_photo.license,
                 "Wrong license, expecting #{expected_license.display_name}")
    assert_equal("https://inaturalist-open-data.s3.amazonaws.com/photos/377332865/original.jpeg",
                 inat_obs_photo.url)
  end
end
