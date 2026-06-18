# frozen_string_literal: true

# Abstract image-shaped carousel-slide inner content: the `<img>` +
# optional stretched link + lightbox link + carousel-caption (just the
# image-vote bar) that goes inside a `Components::Carousel` slide
# registered via `c.item(...) { … }`. Subclasses just override
# `initialize` to set their context-specific defaults (image size,
# `original`, extra classes).
#
# Concrete subclasses:
# - `Components::ImageGallery::Item` — show-page slide,
#   `:large` + `original: true` (full-resolution view inside the
#   show-page Panel).
# - `Components::Matrix::Carousel::Item` — per-matrix-box slide,
#   `:medium` + `original: false` (per the matrix-box-carousel
#   performance budget — see
#   `.claude/rules/matrix_box_carousel.md`).
#
# `Components::Form::UploadGallery::Item` does NOT subclass this:
# its slide layout is a row of `image-col` + `form-col` + control
# buttons, not the read-only `img + caption` shape.
#
# Image copyright / notes / original-name belong on the LIGHTBOX
# caption (the `data-sub-html` attribute of the lightbox link, built
# by `Components::Image::Lightbox::Caption`). They are NOT emitted in
# the visible carousel-caption overlay — that overlay is for the
# vote bar only, so the slide image stays readable.
class Components::Carousel::Item < Components::Image::Base
  prop :object, _Nilable(::AbstractModel), default: nil

  # Defaults that are constant across every carousel slide in the
  # codebase. Subclasses add the context-specific bits (`size`,
  # `original`).
  def initialize(**props)
    props[:fit] ||= :contain
    props[:extra_classes] ||= "carousel-image"
    super
  end

  def view_template
    @img_instance, @img_id = extract_image_and_id
    @data = build_render_data(@img_instance, @img_id)

    render_carousel_image
    render_carousel_overlays
    render_carousel_caption
  end

  private

  def render_carousel_image
    img(
      src: @data[:img_src],
      alt: @notes,
      class: @data[:img_class],
      data: @data[:img_data]
    )
  end

  def render_carousel_overlays
    render_stretched_link if @user && @data[:image_link]
    render_lightbox_link if @data[:lightbox_data]
  end

  def render_carousel_caption
    div(class: "carousel-caption") { render_image_vote_section }
  end
end
