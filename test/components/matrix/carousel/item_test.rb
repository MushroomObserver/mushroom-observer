# frozen_string_literal: true

require("test_helper")

# `Components::Matrix::Carousel::Item` is a thin subclass of
# `Components::Carousel::Item` (the shared image-slide DOM) that only
# customizes `initialize`'s defaults for the per-matrix-box context.
# The rendered DOM contract is inherited from the base; this test
# just pins the defaults so a future tweak to the base or a
# careless `initialize` rewrite can't silently regress the perf
# budget the matrix-box-carousel guidance establishes.
class MatrixCarouselItemTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @image = images(:connected_coprinus_comatus_image)
    @observation = observations(:detailed_unknown_obs)
  end

  # `:medium` (640px) is the matrix-box budget. `:large` (960px) is
  # what `ImageGallery::Item` uses for the show page; if this slide
  # ends up there by accident, an obs-index of N boxes ships
  # N·full-resolution images and we re-hit the perf landmine the
  # original `nimmo-matrix-box-carousels` branch died on.
  def test_default_size_is_medium_not_large
    html = render_item

    assert_html(html, "img[src*='/640/']")
    assert_no_html(html, "img[src*='/960/']")
  end

  # `original: false` — the slide shouldn't carry an `original-name`
  # caption (which requires the `@original` flag to be true).
  def test_default_original_is_false
    html = render_item

    assert_no_html(html, ".image-original-name")
  end

  # The base's "always-the-same" defaults flow through — `:contain`
  # fit + `carousel-image` class on the `<img>`.
  def test_inherited_base_defaults_apply
    html = render_item

    assert_html(html, "img.object-fit-contain.carousel-image")
  end

  # Caller-supplied props win over the subclass's defaults — the
  # standard `props[:foo] ||= default` pattern allows an override.
  # Assert against the `<img>` src specifically (the lightbox link
  # still points at the larger size, which is fine).
  def test_caller_overrides_default_size
    html = render_item(size: :small)

    assert_html(html, "img[src*='/320/']")
    assert_no_html(html, "img[src*='/640/']")
  end

  private

  def render_item(**overrides)
    render(Components::Matrix::Carousel::Item.new(
             user: @user, image: @image, object: @observation, **overrides
           ))
  end
end
