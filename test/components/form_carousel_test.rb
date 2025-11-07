# frozen_string_literal: true

require "test_helper"

class FormCarouselTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @user = users(:rolf)
    @obs = observations(:coprinus_comatus_obs)
    @images = @obs.images.to_a
    @exif_data = {}
  end

  def test_renders_form_carousel_with_images
    component = Components::FormCarousel.new(
      user: @user,
      images: @images,
      thumb_id: @images.first.id,
      exif_data: @exif_data
    )
    html = render(component)

    # Basic structure
    assert_includes(html, "carousel")
    assert_includes(html, "image-form-carousel")
    assert_includes(html, "carousel-inner")
    assert_includes(html, "carousel-item")

    # Should have carousel controls
    assert_includes(html, "carousel-control-wrap")
    assert_includes(html, "carousel-control")
    # FormCarousel uses different control classes (left/right)
    assert_includes(html, 'data-slide="prev"')
    assert_includes(html, 'data-slide="next"')

    # Should have correct data attributes for Stimulus
    assert_includes(html, 'data-ride="false"')
    assert_includes(html, 'data-interval="false"')
    assert_includes(html, 'data-form-images-target="carousel"')
    assert_includes(html, 'data-form-exif-target="carousel"')
  end

  def test_renders_carousel_items_in_carousel_inner
    component = Components::FormCarousel.new(
      user: @user,
      images: @images,
      exif_data: @exif_data
    )
    html = render(component)

    # Carousel items should be inside carousel-inner
    assert_nested(
      html,
      parent_selector: ".carousel-inner",
      child_selector: ".carousel-item"
    )

    # Should have added_images ID
    assert_includes(html, "added_images")
    assert_nested(
      html,
      parent_selector: "#added_images.carousel-inner",
      child_selector: ".carousel-item"
    )
  end

  def test_renders_thumbnail_navigation
    component = Components::FormCarousel.new(
      user: @user,
      images: @images,
      exif_data: @exif_data
    )
    html = render(component)

    # Should have thumbnail navigation
    assert_includes(html, "carousel-indicators")
    assert_includes(html, "added_thumbnails")

    # Thumbnail list has panel-footer class
    assert_includes(html, "panel-footer")
    assert_nested(
      html,
      parent_selector: ".carousel-indicators.panel-footer",
      child_selector: "li"
    )

    # Should have specific ID
    assert_nested(
      html,
      parent_selector: "#added_thumbnails",
      child_selector: "li"
    )
  end

  def test_renders_with_custom_html_id
    component = Components::FormCarousel.new(
      user: @user,
      images: @images,
      html_id: "custom_carousel_id",
      exif_data: @exif_data
    )
    html = render(component)

    assert_includes(html, "custom_carousel_id")
    # Controls should reference custom ID
    assert_includes(html, 'data-target="#custom_carousel_id"')
  end

  def test_uses_default_html_id
    component = Components::FormCarousel.new(
      user: @user,
      images: @images,
      exif_data: @exif_data
    )
    html = render(component)

    # Should have default ID
    assert_includes(html, "observation_upload_images_carousel")
  end

  def test_renders_with_empty_images
    component = Components::FormCarousel.new(
      user: @user,
      images: [],
      exif_data: @exif_data
    )
    html = render(component)

    # Should still render carousel structure
    assert_includes(html, "carousel")
    assert_includes(html, "carousel-inner")
    # But no carousel items
    assert_not_includes(html, "carousel-item")
    # Still has controls
    assert_includes(html, "carousel-control-wrap")
  end

  def test_renders_with_nil_images
    component = Components::FormCarousel.new(
      user: @user,
      images: nil,
      exif_data: @exif_data
    )
    html = render(component)

    # Should render without errors
    assert_includes(html, "carousel")
    assert_includes(html, "carousel-inner")
  end

  def test_passes_thumb_id_to_carousel_items
    thumb_id = @images.first.id
    component = Components::FormCarousel.new(
      user: @user,
      images: @images,
      thumb_id: thumb_id,
      exif_data: @exif_data
    )
    html = render(component)

    # The carousel item should have the thumb indicator
    # (FormCarouselItem uses this to show "Set as thumbnail" button)
    assert_includes(html, "carousel-item")
  end

  def test_handles_exif_data
    image = @images.first
    exif_data = {
      image.id => {
        lat: "45.5",
        lng: "-122.6",
        alt: "100m"
      }
    }

    component = Components::FormCarousel.new(
      user: @user,
      images: @images,
      exif_data: exif_data
    )
    html = render(component)

    # Should render with camera info
    assert_includes(html, "carousel-item")
    # EXIF data gets passed to FormCarouselItem which displays it
  end

  def test_carousel_structure_and_nesting
    component = Components::FormCarousel.new(
      user: @user,
      images: @images,
      exif_data: @exif_data
    )
    html = render(component)

    # Root carousel div
    assert_nested(
      html,
      parent_selector: ".carousel.image-form-carousel",
      child_selector: ".carousel-inner"
    )

    # Carousel inner contains items and controls
    assert_nested(
      html,
      parent_selector: "#added_images",
      child_selector: ".carousel-control-wrap"
    )

    # Thumbnails at same level as carousel-inner
    doc = Nokogiri::HTML(html)
    carousel = doc.at_css(".carousel.image-form-carousel")
    assert(carousel, "Should have carousel")
    assert(carousel.at_css(".carousel-inner"), "Should have carousel-inner")
    assert(carousel.at_css(".carousel-indicators"), "Should have indicators")
  end
end
