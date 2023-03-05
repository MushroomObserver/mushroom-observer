# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Images
  class EXIFControllerTest < FunctionalTestCase
    def test_exif_gps_hidden
      image = images(:in_situ_image)
      image.update_attribute(:transferred, false)

      fixture = "#{MO.root}/test/images/geotagged.jpg"
      file = image.local_file_name("orig")
      path = file.sub(%r{/[^/]*$}, "")
      FileUtils.mkdir_p(path) unless File.directory?(path)
      FileUtils.cp(fixture, file)

      login
      get(:show, params: { id: image.id })
      assert_match(/latitude|longitude/i, @response.body)

      image.observations.first.update_attribute(:gps_hidden, true)
      get(:show, params: { id: image.id })
      assert_no_match(/latitude|longitude/i, @response.body)
    end

    def test_exif_parser
      fixture = "#{MO.root}/test/images/geotagged.jpg"
      result, _status = Open3.capture2e("exiftool", fixture)
      unstripped = @controller.test_parse_exif_data(result, false)
      assert_not_empty(unstripped.select do |key, _val|
                         key.match(/latitude|longitude|gps/i)
                       end)
      stripped = @controller.test_parse_exif_data(result, true)
      assert_empty(stripped.select do |key, _val|
                     key.match(/latitude|longitude|gps/i)
                   end)
    end
  end
end
