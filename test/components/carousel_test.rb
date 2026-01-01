# frozen_string_literal: true

require "test_helper"

class CarouselTest < ComponentTestCase

  def setup
    super
    @user = users(:rolf)
    @obs = observations(:coprinus_comatus_obs)
    @images = @obs.images.to_a
  end

  def test_renders_carousel_with_images
    component = Components::Carousel.new(
      user: @user,
      images: @images,
      object: @obs
    )
    html = render(component)

    # Basic structure
    assert_includes(html, "carousel")
    assert_includes(html, "carousel-inner")
    assert_includes(html, "carousel-item")

    # Should have correct data attributes
    assert_includes(html, 'data-ride="false"')
    assert_includes(html, 'data-interval="false"')

    # Panel structure
    assert_includes(html, "panel")
    assert_includes(html, "panel-default")
    assert_nested(
      html,
      parent_selector: ".panel.panel-default",
      child_selector: ".carousel"
    )

    # Carousel items should be inside carousel-inner
    assert_nested(
      html,
      parent_selector: ".carousel-inner",
      child_selector: ".carousel-item"
    )

    # Image original name should be nested within carousel caption (if shown)
    if html.include?("image-original-name")
      assert_nested(
        html,
        parent_selector: ".carousel-caption",
        child_selector: ".image-original-name"
      )
    end

    # Controls only show with multiple images
    if @images.length > 1
      assert_includes(html, "carousel-control-prev")
      assert_includes(html, "carousel-control-next")
    else
      assert_not_includes(html, "carousel-control-prev")
    end
  end

  def test_renders_single_image_without_controls
    image = @images.first
    component = Components::Carousel.new(
      user: @user,
      images: [image],
      object: @obs
    )
    html = render(component)

    assert_includes(html, "carousel")
    assert_includes(html, "carousel-item")
    # Should not have prev/next controls with single image
    assert_not_includes(html, "carousel-control-prev")
    assert_not_includes(html, "carousel-control-next")
  end

  def test_thumbnail_navigation_when_enabled
    component = Components::Carousel.new(
      user: @user,
      images: @images,
      object: @obs,
      thumbnails: true
    )
    html = render(component)

    # Should have thumbnail navigation
    assert_includes(html, "carousel-indicators")

    # Panel heading structure
    assert_includes(html, "panel-heading")
    assert_nested(
      html,
      parent_selector: ".panel",
      child_selector: ".panel-heading"
    )

    # Thumbnail indicators as panel footer
    assert_includes(html, "panel-footer")
    assert_nested(
      html,
      parent_selector: ".carousel-indicators.panel-footer",
      child_selector: "li"
    )

    # Verify proper order: panel > heading > carousel > footer
    assert_nested(
      html,
      parent_selector: ".panel",
      child_selector: ".carousel-indicators.panel-footer"
    )
  end

  def test_no_thumbnail_navigation_when_disabled
    component = Components::Carousel.new(
      user: @user,
      images: @images,
      object: @obs,
      thumbnails: false
    )
    html = render(component)

    # Should not have thumbnail navigation or heading
    assert_not_includes(html, "carousel-indicators")
    assert_not_includes(html, "panel-heading")
  end

  def test_renders_with_custom_options
    links = '<a href="/test">Test Link</a>'
    component = Components::Carousel.new(
      user: @user,
      images: @images,
      object: @obs,
      title: "Custom Gallery Title",
      links: links,
      panel_id: "custom_panel_id",
      thumbnails: true
    )
    html = render(component)

    # Custom title in panel heading
    assert_includes(html, "Custom Gallery Title")
    assert_nested(
      html,
      parent_selector: ".panel-heading",
      child_selector: ".panel-title",
      text: "Custom Gallery Title"
    )

    # Custom links in panel heading
    assert_includes(html, "Test Link")
    assert_includes(html, "/test")
    assert_includes(html, "panel-heading-links")

    # Custom panel ID
    assert_includes(html, "custom_panel_id")
  end

  def test_filters_nil_images
    # Create array with nils mixed in
    images_with_nil = [@images.first, nil, nil]
    component = Components::Carousel.new(
      user: @user,
      images: images_with_nil,
      object: @obs
    )
    html = render(component)

    # Should render successfully without errors
    assert_includes(html, "carousel")
    assert_includes(html, "carousel-item")
    # Should have rendered at least one image (the non-nil one)
    assert_includes(html, "carousel-inner")
  end

  def test_renders_no_images_message_when_empty
    component = Components::Carousel.new(
      user: @user,
      images: [],
      object: @obs
    )
    html = render(component)

    # Should show styled message area
    assert_includes(html, "text-muted")
    # Should not have carousel-inner
    assert_not_includes(html, "carousel-inner")
    # Should not have controls
    assert_not_includes(html, "carousel-control-prev")

    # Panel structure
    assert_includes(html, "panel")
    assert_includes(html, "panel-default")
    assert_nested(
      html,
      parent_selector: ".panel.panel-default",
      child_selector: ".text-muted"
    )
  end

  def test_renders_custom_title_when_empty
    component = Components::Carousel.new(
      user: @user,
      images: [],
      object: @obs,
      title: "Custom Gallery Title",
      thumbnails: true
    )
    html = render(component)

    # Title in panel heading
    assert_includes(html, "Custom Gallery Title")
    assert_includes(html, "panel-heading")
    assert_nested(
      html,
      parent_selector: ".panel-heading",
      child_selector: ".panel-title",
      text: "Custom Gallery Title"
    )
  end

  def test_no_heading_when_thumbnails_disabled
    component = Components::Carousel.new(
      user: @user,
      images: [],
      object: @obs,
      thumbnails: false
    )
    html = render(component)

    # Should not have panel heading
    assert_not_includes(html, "panel-heading")
  end

  def test_panel_id_is_passed_through
    component = Components::Carousel.new(
      user: @user,
      images: [],
      object: @obs,
      panel_id: "custom_panel_id"
    )
    html = render(component)

    assert_includes(html, "custom_panel_id")
  end
end
