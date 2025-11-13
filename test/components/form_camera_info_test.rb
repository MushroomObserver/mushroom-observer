# frozen_string_literal: true

require "test_helper"

class FormCameraInfoTest < UnitTestCase
  include ComponentTestHelper

  def test_renders_gps_info_with_all_values
    component = Components::FormCameraInfo.new(
      img_id: 123,
      lat: "45.5231",
      lng: "-122.6765",
      alt: "100",
      date: "2024-01-15",
      file_name: "IMG_1234.jpg",
      file_size: "2.5 MB"
    )
    html = render(component)

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
    component = Components::FormCameraInfo.new(
      img_id: 123,
      lat: "",
      lng: "",
      alt: "",
      date: "2024-01-15",
      file_name: "IMG_1234.jpg",
      file_size: "2.5 MB"
    )
    html = render(component)

    # Should always render GPS span so JavaScript can populate it
    assert_includes(html, 'class="exif_gps"')
    # All wrapper spans should have d-none class when values are blank
    assert_includes(html, 'class="exif_lat_wrapper d-none"')
    assert_includes(html, 'class="exif_lng_wrapper d-none"')
    assert_includes(html, 'class="exif_alt_wrapper d-none"')
  end

  def test_renders_partial_gps_info
    component = Components::FormCameraInfo.new(
      img_id: 123,
      lat: "45.5231",
      lng: "",
      alt: "100",
      date: "2024-01-15",
      file_name: "IMG_1234.jpg",
      file_size: "2.5 MB"
    )
    html = render(component)

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
    component = Components::FormCameraInfo.new(
      img_id: 123,
      date: "2024-01-15",
      file_name: "IMG_1234.jpg",
      file_size: "2.5 MB"
    )
    html = render(component)

    assert_includes(html, "IMG_1234.jpg")
    assert_includes(html, "2.5 MB")
  end

  def test_always_renders_no_gps_message_with_d_none
    component = Components::FormCameraInfo.new(
      img_id: 123,
      lat: "45.5231",
      lng: "-122.6765",
      alt: "100",
      date: "2024-01-15",
      file_name: "IMG_1234.jpg",
      file_size: "2.5 MB"
    )
    html = render(component)

    # Should always render no GPS message with d-none class
    # (Stimulus controller will show it if needed)
    assert_includes(html, "exif_no_gps d-none")
  end

  def test_accepts_float_values_for_gps_coordinates
    component = Components::FormCameraInfo.new(
      img_id: 123,
      lat: 45.5231, # Float
      lng: -122.6765, # Float
      alt: 100.5, # Float
      date: "2024-01-15",
      file_name: "IMG_1234.jpg",
      file_size: "2.5 MB"
    )
    html = render(component)

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
    component = Components::FormCameraInfo.new(
      img_id: 123,
      lat: 45, # Integer
      lng: -122, # Integer
      alt: 100, # Integer
      date: "2024-01-15"
    )
    html = render(component)

    # Should convert integers to strings and render correctly
    assert_includes(html, "45")
    assert_includes(html, "-122")
    assert_includes(html, "100")
  end
end
