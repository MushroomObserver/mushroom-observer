# frozen_string_literal: true

require("test_helper")

# test mapping of iNat observation photo key/values to MO Image attributes
class InatObsPhotoTest < UnitTestCase
  def test_simple_photo
    mock_search = File.read("test/inat/tremella_mesenterica.txt")
    inat_obs = Inat::Obs.new(
      JSON.generate(JSON.parse(mock_search)["results"].first)
    )
    photo = Inat::ObsPhoto.new(inat_obs[:observation_photos].first)

    expected_license =
      License.where(License[:url] =~ "/by-nc/").where(deprecated: false).
      order(id: :asc).last

    assert_equal("img/jpeg", photo.content_type)
    assert_equal("(c) Tim C., some rights reserved (CC BY-NC)",
                 photo.copyright_holder)
    assert_equal("iNat photo uuid 6c223538-04d6-404c-8e84-b7d881dbe550",
                 photo.original_name)
    assert_equal(
      "Imported from iNat #{DateTime.now.utc.strftime("%Y-%m-%d %H:%M:%S %z")}",
      photo.notes
    )

    assert_equal(expected_license, photo.license,
                 "Wrong license, expecting #{expected_license.display_name}")
    assert_equal("https://inaturalist-open-data.s3.amazonaws.com/photos/377332865/original.jpeg",
                 photo.url)
  end
end
