# frozen_string_literal: true

require("test_helper")

# `Components::Grid::Box::Carousel` is the third caller of
# `Components::Carousel` (after `ImageGallery` and
# `Form::UploadGallery`). It exists ahead of the obs-index integration
# so the primitive's API is validated by all three consumers.
class Components::Grid::Box::CarouselTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @observation = observations(:detailed_unknown_obs)
    @images = @observation.images.to_a
    skip("Fixture has no images") if @images.empty?
  end

  # Skeleton: panel-less outer carousel-slide div with the standard
  # data-ride / data-interval attrs and the derived carousel id.
  def test_renders_panel_less_carousel_skeleton
    html = render_carousel

    assert_html(html, "div.carousel.slide[data-ride='false']" \
                      "[data-interval='false']" \
                      "[id='observation_#{@observation.id}_carousel']")
    assert_html(html, "div.carousel.slide > div.carousel-inner" \
                      "[role='listbox']")
    # No Panel wrapper, no indicator strip — those are contracts
    # specific to the box context (the box itself owns the
    # surrounding card; thumbnails are not shown per-box).
    assert_no_html(html, "div.card")
    assert_no_html(html, "ol.carousel-indicators")
  end

  # One `<div class="item">` per image. Without an explicit `top_img`,
  # the first slide is the active one (primitive default).
  def test_one_slide_per_image_with_default_first_active
    html = render_carousel

    slide_count = html.scan(/class="item[^"]*"/).size
    assert_equal(@images.length, slide_count)
    # First image's wrapper id ends with the first image's id.
    assert_html(html, "div.item.active" \
                      "[id='carousel_item_#{@images.first.id}']")
  end

  # `top_img` shifts `.active` to a non-first slide. Critical for
  # the box use case: a box returning to a previously-viewed
  # image should highlight it, not the first.
  def test_top_img_overrides_active_slide
    skip("Need ≥2 images") if @images.length < 2

    target = @images[1]
    html = render_carousel(top_img: target)

    assert_html(html, "div.item.active[id='carousel_item_#{target.id}']")
    # First image's slide is NOT active.
    assert_no_html(html,
                   "div.item.active[id='carousel_item_#{@images.first.id}']")
  end

  # Controls render iff >1 image (primitive's `show_controls` is driven
  # by `@images.length > 1`).
  def test_controls_present_when_multiple_images
    skip("Need ≥2 images") if @images.length < 2

    html = render_carousel

    assert_html(html, "button.carousel-control-prev")
    assert_html(html, "button.carousel-control-next")
  end

  # Item slide does NOT pull a `:large`/original image — the
  # `Grid::Box::Carousel::Item` subclass overrides defaults to keep the
  # per-box render cost down.
  # The img's `src` should be a `medium` (640px) variant rather than
  # the `:original`/`:huge`/`:large` URL.
  def test_slides_use_medium_size_not_large
    html = render_carousel

    assert_includes(html, "/640/")
    assert_not_includes(html, "/960/")  # :large
    assert_not_includes(html, "/orig/") # :original
  end

  # Empty images set — render nothing (the caller would normally gate
  # this upstream, but the component shouldn't crash).
  def test_empty_images_renders_nothing
    html = render(Components::Grid::Box::Carousel.new(
                    user: @user, object: @observation, images: []
                  ))
    assert_equal("", html)
  end

  private

  def render_carousel(top_img: nil)
    render(Components::Grid::Box::Carousel.new(
             user: @user, object: @observation,
             images: @images, top_img: top_img
           ))
  end
end
