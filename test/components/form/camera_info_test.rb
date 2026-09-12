# frozen_string_literal: true

require "test_helper"

class FormCameraInfoTest < ComponentTestCase
  def test_renders_gps_info_with_all_values
    html = render_info(lat: "45.5231", lng: "-122.6765", alt: "100")

    # Should render GPS info with proper format
    assert_includes(html, "exif_gps")
    assert_includes(html, "exif_lat")
    assert_includes(html, "45.5231")
    assert_includes(html, "exif_lng")
    assert_includes(html, "-122.6765")
    assert_includes(html, "exif_alt")
    assert_includes(html, "100")

    # Wrappers should not have d-none class when values are present
    assert_includes(html, 'class="exif_lat_wrapper"')
    assert_includes(html, 'class="exif_lng_wrapper"')
    assert_includes(html, 'class="exif_alt_wrapper"')
  end

  def test_renders_blank_gps_info_when_no_values
    html = render_info(lat: "", lng: "", alt: "")

    # Should always render GPS span so JavaScript can populate it
    assert_html(html, "span.exif_gps")
    # All wrapper spans should have d-none class when values are blank
    assert_html(html, "span.exif_lat_wrapper.d-none")
    assert_html(html, "span.exif_lng_wrapper.d-none")
    assert_html(html, "span.exif_alt_wrapper.d-none")
  end

  def test_renders_partial_gps_info
    html = render_info(lat: "45.5231", lng: "", alt: "100")

    # Should render only lat and alt
    assert_includes(html, "45.5231")
    assert_includes(html, "100")
    # Wrappers with values should not have d-none class
    assert_includes(html, 'class="exif_lat_wrapper"')
    assert_includes(html, 'class="exif_alt_wrapper"')
    # Wrapper without value should have d-none class
    assert_includes(html, 'class="exif_lng_wrapper d-none"')
  end

  def test_renders_file_info
    html = render_info(file_name: "IMG_1234.jpg", file_size: "2.5 MB")

    assert_includes(html, "IMG_1234.jpg")
    assert_includes(html, "2.5 MB")
  end

  # File size row is dropped when there's no size (e.g. a reflection
  # image), rather than showing an empty "File size:" label.
  def test_hides_file_size_when_absent
    html = render_info(file_name: "IMG_1234.jpg", file_size: nil)

    assert_html(html, "span.file_name", text: "IMG_1234.jpg")
    assert_no_html(html, "span.file_size")
    assert_not_includes(html, :image_file_size.l)
  end

  def test_always_renders_no_gps_message_with_d_none
    html = render_info(lat: "45.5231", lng: "-122.6765", alt: "100")

    # Should always render no GPS message with d-none class
    # (Stimulus controller will show it if needed)
    assert_includes(html, "exif_no_gps d-none")
  end

  def test_accepts_float_values_for_gps_coordinates
    html = render_info(lat: 45.5231, lng: -122.6765, alt: 100.5)

    # Should convert floats to strings and render correctly
    assert_includes(html, "45.5231")
    assert_includes(html, "-122.6765")
    assert_includes(html, "100.5")

    # Wrappers should not have d-none class when values are present
    assert_includes(html, 'class="exif_lat_wrapper"')
    assert_includes(html, 'class="exif_lng_wrapper"')
    assert_includes(html, 'class="exif_alt_wrapper"')
  end

  def test_accepts_integer_values_for_gps_coordinates
    html = render_info(lat: 45, lng: -122, alt: 100)

    # Should convert integers to strings and render correctly
    assert_includes(html, "45")
    assert_includes(html, "-122")
    assert_includes(html, "100")
  end

  # A read-only reflection image shows the read-only note, immutable
  # copyright/license, and a link to the source observation.
  def test_read_only_reflection_panel
    html = render_info(read_only: true, copyright_holder: "(c) Jane",
                       license_name: "CC BY-NC", date_differs: true,
                       source_url: "https://www.inaturalist.org/observations/9")

    assert_includes(html, :image_reflection_info.l)
    assert_html(html, "div.reflection_readonly_note",
                text: :image_reflection_readonly_note.l)
    assert_html(html, "span.reflection_copyright", text: "(c) Jane")
    assert_html(html, "span.reflection_license", text: "CC BY-NC")
    assert_html(
      html,
      "a.reflection_source_link" \
      "[href='https://www.inaturalist.org/observations/9']"
    )
  end

  # Read-only with a location OR a differing date offers "Use this info".
  def test_read_only_shows_use_this_info_when_adoptable
    with_location = render_info(read_only: true, lat: "45.5", lng: "-122.6")
    assert_html(with_location, "button.use_exif_btn:not(.d-none)")

    date_only = render_info(read_only: true, date_differs: true)
    assert_html(date_only, "button.use_exif_btn:not(.d-none)")
  end

  # Read-only with no location and the same date has nothing to adopt.
  def test_read_only_hides_use_this_info_when_nothing_to_adopt
    html = render_info(read_only: true, date_differs: false)

    assert_html(html, "button.use_exif_btn.d-none")
  end

  # A saved image (upload: false, the default everywhere else in this
  # file) loads its date/GPS fields lazily from the server instead of
  # rendering them directly -- see issue #5369.
  def test_saved_image_renders_lazy_exif_frame
    html = render_info(upload: false)

    assert_html(html, "turbo-frame#camera_info_exif_123")
    assert_no_html(html, "span.exif_gps")
    assert_no_html(html, "button.use_exif_btn")
  end

  def test_upload_image_renders_fields_directly
    html = render_info(upload: true, lat: "45.5231")

    assert_no_html(html, "turbo-frame")
    assert_html(html, "span.exif_gps")
  end

  private

  # rubocop:disable-next Metrics/ParameterLists
  def render_info(lat: nil, lng: nil, alt: nil, date: "2024-01-15",
                  file_name: nil, file_size: nil, read_only: false,
                  copyright_holder: nil, license_name: nil,
                  source_url: nil, date_differs: false, upload: true)
    render(Components::Form::CameraInfo.new(
             img_id: 123, upload: upload, lat: lat, lng: lng, alt: alt,
             date: date, file_name: file_name, file_size: file_size,
             read_only: read_only, copyright_holder: copyright_holder,
             license_name: license_name, source_url: source_url,
             date_differs: date_differs
           ))
  end
end
