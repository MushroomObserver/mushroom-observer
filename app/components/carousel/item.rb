# frozen_string_literal: true

# Abstract image-shaped carousel-slide inner content: the `<img>` +
# optional stretched link + lightbox link + carousel-caption (vote bar
# + optional original-filename) that goes inside a
# `Components::Carousel` slide registered via `c.item(...) { … }`.
# Subclasses just override `initialize` to set their context-specific
# defaults (image size, `original`, extra classes).
#
# Concrete subclasses:
# - `Components::ImageGallery::Item` — show-page slide,
#   `:large` + `original: true` (full-resolution view inside the
#   show-page Panel).
# - `Components::Matrix::Carousel::Item` — per-matrix-box slide,
#   `:medium` + `original: false` (keeps per-box render cost down;
#   the lightbox is the explicit path to full resolution).
#
# `Components::Form::UploadGallery::Item` does NOT subclass this:
# its slide layout is a row of `image-col` + `form-col` + control
# buttons, not the read-only `img + caption` shape.
#
# Image **copyright** and **notes** belong on the LIGHTBOX caption
# (the `data-sub-html` attribute of the lightbox link, built by
# `Components::Image::Lightbox::Caption`). They are NOT emitted in
# the visible carousel-caption overlay.
#
# Image **original filename** IS visible in the carousel-caption
# (inside the `.image-info.d-none.d-sm-block` wrapper, hidden on xs
# and visible from sm+ viewports) when both conditions hold:
#   - the slide is in `original: true` mode (the show-page gallery is;
#     the matrix-box carousel is not),
#   - the image owner has `keep_filenames == "keep_and_show"`
#     OR the viewing user has edit permission on the image.
# `LurkerIntegrationTest#test_show_observation` pins this contract
# (a lurker viewing a rolf-owned image must see the original
# filename when rolf has opted into showing it).
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
    div(class: "carousel-caption") do
      render_image_vote_section
      render_image_info_section if image_info_visible?
    end
  end

  # Side-effect-free predicate. The earlier shape was
  # `if image_info_html.present?` where `image_info_html` had Phlex
  # render side effects — that leaked copyright/notes into the
  # carousel-caption buffer outside the `.image-info` wrapper. The
  # only thing the carousel-caption shows from `image-info` now is
  # the original filename, gated solely on `show_original_name?`.
  def image_info_visible?
    show_original_name? && @img_instance.original_name.present?
  end

  def render_image_info_section
    div(class: "image-info d-none d-sm-block") do
      div(class: "image-original-name") { @img_instance.original_name }
    end
  end

  def show_original_name?
    @original && @img_instance &&
      @img_instance.original_name.present? &&
      (permission?(@img_instance) ||
       @img_instance.user &&
       @img_instance.user.keep_filenames == "keep_and_show")
  end
end
