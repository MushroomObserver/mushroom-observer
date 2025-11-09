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

    # Check that values are separated by commas
    assert_includes(html, "45.5231</span>, ")
    assert_includes(html, "-122.6765</span>, ")
    assert_includes(html, "100</span>")
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

    # Should NOT render GPS span when all values are blank
    assert_not_includes(html, 'class="exif_gps"')
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
    # Should have comma separator between values
    assert_includes(html, "45.5231</span>, ")
    assert_includes(html, "100</span>")
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
end
