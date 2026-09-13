# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images::EXIFGeocode
  class ShowTest < ComponentTestCase
    def test_renders_matching_turbo_frame_with_geocode_data
      html = render_show(img_id: "42", lat: 45.5231, lng: -122.6765,
                         alt: 100.0,
                         date: SimpleDate.new(day: 15, month: 1, year: 2024))

      assert_html(html, "turbo-frame#camera_info_exif_42")
      assert_html(
        html,
        'turbo-frame[data-geocode*=\'"lat":45.5231\']'
      )
      assert_html(html, "span.exif_lat_wrapper:not(.d-none)")
      assert_html(html, "button.use_exif_btn:not(.d-none)")
      # data-exif-date must be JSON matching form-exif_controller.js's
      # SimpleDate shape ({day:, month:, year:}), not the display
      # string -- the JS JSON.parses it when transferring/clicking.
      assert_html(
        html,
        "turbo-frame[data-exif-date=" \
        '\'{"day":15,"month":1,"year":2024}\']'
      )
    end

    # No lat/lng means an empty geocode -- "Use this info" still shows
    # if the date differs from the primary's (#5317).
    def test_geocode_empty_string_when_no_location
      html = render_show(img_id: "7",
                         date: SimpleDate.new(day: 1, month: 1, year: 2024),
                         date_differs: true)

      assert_html(html, "turbo-frame#camera_info_exif_7[data-geocode='']")
      assert_html(html, "span.exif_lat_wrapper.d-none")
      assert_html(html, "button.use_exif_btn:not(.d-none)")
    end

    private

    def render_show(**)
      render(Show.new(**))
    end
  end
end
