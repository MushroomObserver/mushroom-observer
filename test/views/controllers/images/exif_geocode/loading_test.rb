# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images::EXIFGeocode
  class LoadingTest < ComponentTestCase
    def test_renders_matching_turbo_frame_with_spinner
      html = render(Loading.new(img_id: "42"))

      assert_html(html, "turbo-frame#camera_info_exif_42")
      assert_html(html, "turbo-frame .spinner-right")
    end
  end
end
