# frozen_string_literal: true

# Per-matrix-box mini-carousel — the planned image-set rendering for the
# observations index. Wraps the `Components::Carousel` primitive with
# matrix-box-appropriate chrome: no Panel, no thumbnail strip
# (`show_indicators: false`), the active slide chosen via `top_img`
# rather than the default "first slide active" (so a box returning to
# a previously-viewed slide can highlight it).
#
# Reproduces the rendered HTML the abandoned `nimmo-matrix-box-carousels`
# branch produced. Sidesteps its full-resolution (`:large`/`original: true`)
# images-per-slide landmine by using a smaller lazy-loaded size. Callers must
# preload `images` (e.g. `includes(:images)`) to avoid an N+1 query per box.
#
# Not yet consumed by the obs-index — landing as L1 ahead of the
# obs-index integration so the abstraction is validated by a third
# caller (alongside `ImageGallery` and `Form::UploadGallery`) and
# can be browsed in isolation via a dev test route.
#
# @example
#   render Components::Matrix::Carousel.new(
#     user: @user,
#     object: observation,
#     images: observation.images,
#     top_img: observation.thumb_image || observation.images.first
#   )
class Components::Matrix::Carousel < Components::Base
  prop :images, _Array(::Image) do |value|
    value.respond_to?(:to_a) ? value.to_a : value
  end
  prop :user, _Nilable(::User)
  prop :object, _Nilable(::AbstractModel), default: nil
  # The slide that should render as `.active`. Defaults to
  # `images.first` (which makes Matrix::Carousel behave like every
  # other carousel — first slide active).
  prop :top_img, _Nilable(::Image), default: nil
  prop :carousel_id, _Nilable(::String), default: nil

  def view_template
    @carousel_id ||= generate_carousel_id
    return if @images.empty?

    # Must stay `render(Components::Carousel.new(...))`, not bare
    # `Carousel(...)` Kit syntax -- this component class is itself
    # named `Carousel` (Components::Matrix::Carousel), so Kit's
    # constant lookup would recurse into itself instead of resolving
    # Components::Carousel (see commit 33fdc952e5 for the same bug
    # with a view class named `Table`).
    render(Components::Carousel.new(
             carousel_id: @carousel_id,
             show_controls: @images.length > 1,
             show_indicators: false
           )) do |c|
      register_slides(c)
    end
  end

  private

  def generate_carousel_id
    type = @object&.type_tag || "image"
    object_id = @object&.id || "unknown"
    "#{type}_#{object_id}_carousel"
  end

  def active_image
    @active_image ||= @top_img || @images.first
  end

  def register_slides(carousel)
    @images.each do |image|
      carousel.item(id: "carousel_item_#{image.id}",
                    active: image == active_image) do
        render(Components::Matrix::Carousel::Item.new(
                 user: @user, image: image, object: @object
               ))
      end
    end
  end
end
