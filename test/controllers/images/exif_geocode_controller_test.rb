# frozen_string_literal: true

require("test_helper")

module Images
  class EXIFGeocodeControllerTest < FunctionalTestCase
    def test_show_with_geotagged_image
      image = images(:in_situ_image)
      image.update_attribute(:transferred, false)
      copy_geotagged_fixture_to(image)

      login
      get(:show, params: { id: image.id })

      assert_response(:success)
      assert_select("turbo-frame#camera_info_exif_#{image.id}")
      assert_select("span.exif_lat_wrapper:not(.d-none)")
      assert_select("button.use_exif_btn:not(.d-none)")
    end

    def test_show_falls_back_to_database_date_with_no_exif
      image = images(:in_situ_image)
      image.update_attribute(:transferred, false)
      FileUtils.rm_f(image.full_filepath("orig"))

      login
      get(:show, params: { id: image.id })

      assert_response(:success)
      assert_select("span.exif_lat_wrapper.d-none")
      assert_select("span.exif_date",
                    text: image.when.strftime("%d-%B-%Y"))
    end

    def test_show_passes_through_read_only_and_date_differs
      image = images(:in_situ_image)
      image.update_attribute(:transferred, false)
      FileUtils.rm_f(image.full_filepath("orig"))

      login
      get(:show, params: { id: image.id, read_only: "true",
                           date_differs: "true" })

      assert_response(:success)
      assert_select("button.use_exif_btn:not(.d-none)")
    end

    private

    def copy_geotagged_fixture_to(image)
      fixture = "#{MO.root}/test/images/geotagged.jpg"
      file = image.full_filepath("orig")
      FileUtils.mkdir_p(File.dirname(file))
      FileUtils.cp(fixture, file)
    end
  end
end
