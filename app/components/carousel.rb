# frozen_string_literal: true

# Bootstrap-3 carousel primitive — the bare skeleton (`<div class="carousel
# slide">` + `<div class="carousel-inner">` + optional controls + optional
# indicator strip) every carousel-shaped component in MO composes.
# Items + thumbnails are registered via `c.item(...) { … }` /
# `c.thumb(...) { … }` — same hybrid pattern as
# `Components::ListGroup`. The primitive owns the
# `<div class="item">` / `<li class="carousel-indicator">` wrappers
# and the caller's block fills the inside.
#
# Consumers:
# - `Components::ImageGallery` — read-only image carousel inside a Panel
#   (show-page IMAGES section).
# - `Components::Form::UploadGallery` — editable image-upload carousel
#   for the observation form.
# - `Components::Matrix::Carousel` — per-matrix-box mini-carousel, not
#   yet consumed by the obs-index (see that class for details).
#
# @example
#   render(Components::Carousel.new(carousel_id: "obs_42")) do |c|
#     @images.each do |image|
#       c.item(id: "carousel_item_#{image.id}", class: "carousel-item") do
#         render(Components::ImageGallery::Item.new(image: image, user: @user))
#       end
#       c.thumb(id: "carousel_thumbnail_#{image.id}",
#               data: { form_images_target: "thumbnail",
#                       image_uuid: image.id, image_status: "good" }) do
#         render(Components::ImageGallery::Thumbnail.new(image: image,
#                                                       user: @user))
#       end
#     end
#   end
class Components::Carousel < Components::Base
  prop :carousel_id, ::String
  prop :wrapper_class, ::String, default: ""
  prop :inner_id, _Nilable(::String), default: nil
  prop :inner_class_extra, ::String, default: ""
  prop :indicators_id, _Nilable(::String), default: nil
  prop :indicators_class_extra, ::String, default: ""
  prop :show_controls, _Boolean, default: true
  prop :show_indicators, _Boolean, default: true
  # Wraps the controls strip in a div with this class.
  # `Form::UploadGallery` puts the prev/next arrows inside a
  # `.carousel-control-wrap.row` outside `.carousel-inner`; default
  # nil renders the controls inline as `ImageGallery` and the
  # matrix-box caller do.
  prop :controls_wrap_class, _Nilable(::String), default: nil
  # Arbitrary `data-*` attributes merged onto the outer `<div>` (after
  # the always-emitted `data-ride="false"` / `data-interval="false"`).
  # Keys are symbols (Phlex/Rails dasherizes them — `:form_images_target`
  # → `data-form-images-target`); values may be strings or anything
  # else that responds to `#to_s` (Phlex stringifies on render).
  prop :extra_data, ::Hash, default: -> { {} }

  def initialize(...)
    super
    @slides = []
    @thumbs = []
  end

  # Register a slide. `class:` / `id:` / arbitrary attrs flow onto the
  # wrapping `<div class="item …">` (mirroring `ListGroup#item`).
  # `active: true` overrides the default first-slide-active behavior
  # (`Matrix::Carousel` uses this to active the slide matching its
  # `top_img`); when no slide is marked active, the first one gets it.
  #
  # @return [nil] so the call doesn't accidentally emit anything
  def item(class: nil, id: nil, active: false, **attrs, &block)
    @slides << {
      class: grab(class:),
      id: id, active: active, attrs: attrs, block: block
    }
    nil
  end

  # Register a thumbnail indicator. `class:` / `id:` / arbitrary attrs
  # flow onto the wrapping `<li class="carousel-indicator …">`. The
  # primitive auto-fills `data-target="#<carousel_id>"` and
  # `data-slide-to="<n>"`; caller-supplied `data:` is merged on top.
  # `active:` works the same as on `#item`.
  #
  # @return [nil]
  def thumb(class: nil, id: nil, active: false, **attrs, &block)
    @thumbs << {
      class: grab(class:),
      id: id, active: active, attrs: attrs, block: block
    }
    nil
  end

  def view_template(&block)
    vanish(self, &block) if block

    div(id: @carousel_id,
        class: class_names("carousel slide", @wrapper_class),
        data: { ride: "false", interval: "false", **@extra_data }) do
      render_inner
      render_indicators if @show_indicators
    end
  end

  private

  def render_inner
    div(id: @inner_id,
        class: class_names("carousel-inner bg-light", @inner_class_extra),
        role: "listbox") do
      @slides.each_with_index { |slide, i| render_slide(slide, i) }
      render_controls if @show_controls
    end
  end

  def render_slide(slide, index)
    div(id: slide[:id],
        class: class_names("item", slide[:class],
                           active_for(@slides, slide, index)),
        **slide[:attrs]) do
      slide[:block]&.call
    end
  end

  def render_thumb(thumb, index)
    base_data = { target: "##{@carousel_id}", slide_to: index.to_s }
    extra = thumb[:attrs][:data] || {}
    rest = thumb[:attrs].except(:data)
    li(id: thumb[:id],
       class: class_names("carousel-indicator mx-1", thumb[:class],
                          active_for(@thumbs, thumb, index)),
       data: base_data.merge(extra),
       **rest) do
      thumb[:block]&.call
    end
  end

  # If any registration marks `active: true`, only those get `.active`.
  # Otherwise the first registration gets it (default behavior).
  def active_for(set, entry, index)
    return "active" if entry[:active]
    return nil if set.any? { |e| e[:active] }

    "active" if index.zero?
  end

  def render_indicators
    ol(id: @indicators_id,
       class: class_names(
         "carousel-indicators panel-footer py-2 px-0 mb-0",
         @indicators_class_extra
       )) do
      @thumbs.each_with_index { |thumb, i| render_thumb(thumb, i) }
    end
  end

  def render_controls
    if @controls_wrap_class
      div(class: @controls_wrap_class) { render_controls_inner }
    else
      render_controls_inner
    end
  end

  def render_controls_inner
    render(Components::Carousel::Controls.new(carousel_id: @carousel_id))
  end
end
