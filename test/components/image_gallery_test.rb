# frozen_string_literal: true

require "test_helper"

class ImageGalleryTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:coprinus_comatus_obs)
    @images = @obs.images.to_a
  end

  def test_renders_carousel_with_images
    component = Components::ImageGallery.new(
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

    # Controls only show with multiple images. Bootstrap 3 markup
    # is `a.left.carousel-control` / `a.right.carousel-control` —
    # `Components::Carousel::Controls#render_control` builds that
    # shape, not the Bootstrap 4 `carousel-control-prev/next` form.
    if @images.length > 1
      assert_html(html, "a.left.carousel-control")
      assert_html(html, "a.right.carousel-control")
    else
      assert_no_html(html, "a.carousel-control")
    end
  end

  # Carousel items embed `Components::ImageGallery::Item`, which inherits from
  # `BaseImage` and dispatches to `Components::Image::VoteInterface` via
  # `render_image_vote_section`. Asserts the dispatch actually emits
  # the vote section markers — a previous version of the dispatch
  # `render(Components::Image::VoteInterface.new(...))` was malformed
  # Phlex and silently no-op'd
  # so the lightbox / carousel never showed votes.
  def test_carousel_item_renders_vote_section
    image = @images.first
    component = Components::ImageGallery.new(
      user: @user, images: [image], object: @obs
    )
    html = render(component)

    assert_html(html, ".carousel-item .vote-section#image_vote_#{image.id}")
    assert_html(html, ".carousel-item .vote-meter.progress")
    assert_html(html, ".carousel-item .image-vote-links")
  end

  def test_renders_single_image_without_controls
    image = @images.first
    component = Components::ImageGallery.new(
      user: @user,
      images: [image],
      object: @obs
    )
    html = render(component)

    assert_includes(html, "carousel")
    assert_includes(html, "carousel-item")
    # Single image → no prev/next controls. Bootstrap 3 markup is
    # `a.carousel-control`, so assert absence of that selector.
    assert_no_html(html, "a.carousel-control")
  end

  def test_thumbnail_navigation_when_enabled
    component = Components::ImageGallery.new(
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
    component = Components::ImageGallery.new(
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
    component = Components::ImageGallery.new(
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
    component = Components::ImageGallery.new(
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
    component = Components::ImageGallery.new(
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
    component = Components::ImageGallery.new(
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
    component = Components::ImageGallery.new(
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
    component = Components::ImageGallery.new(
      user: @user,
      images: [],
      object: @obs,
      panel_id: "custom_panel_id"
    )
    html = render(component)

    assert_includes(html, "custom_panel_id")
  end

  # Regression: the visible `.carousel-caption` overlay on each slide
  # should contain ONLY the vote bar — never image copyright / notes /
  # original-name. Those belong on the lightbox caption
  # (`data-sub-html` on the lightbox link, built by
  # `Components::Image::Lightbox::Caption`).
  #
  # The original bug (caught by the matrix-box tryout): the abstract
  # `Components::Carousel::Item#render_carousel_caption` gated the
  # image-info block on `image_info_html.present?`. That predicate
  # called `image_info_html`, which called `copyright` / `notes` /
  # `owner_original_name` — all of which have Phlex side effects
  # (they write `div(...)` / `render(...)` to the current buffer).
  # The "present?" check therefore wrote copyright + notes directly
  # into the `.carousel-caption` buffer, OUTSIDE the
  # `.image-info.d-none.d-sm-block` wrapper that was supposed to
  # gate visibility. Net effect: copyright + iNat-import note
  # overlaid on every slide instead of being scoped to the lightbox.
  def test_carousel_caption_contains_only_vote_section_no_image_info_leak
    # Fixture has both `notes: "Some Notes"` and
    # `copyright_holder: "Bob Dobbs"` — the exact shape that triggered
    # the leak before. If the abstract `Carousel::Item` ever re-grows
    # an image-info render path inside `render_carousel_caption`,
    # the side-effect emission will trip this assertion.
    leak_image = images(:connected_coprinus_comatus_image)
    leak_obs = leak_image.observations.first || @obs

    html = render(Components::ImageGallery.new(
                    user: @user, images: [leak_image], object: leak_obs
                  ))

    # The vote bar IS in the carousel-caption.
    assert_html(html, ".carousel-caption .vote-section")

    # The image-info contents are NOT in the carousel-caption.
    assert_no_html(html, ".carousel-caption .image-info")
    assert_no_html(html, ".carousel-caption .image-copyright")
    assert_no_html(html, ".carousel-caption .image-notes")
    assert_no_html(html, ".carousel-caption .image-original-name")
  end
end
