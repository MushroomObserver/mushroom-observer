# frozen_string_literal: true

# Panel-wrapped image carousel — the show-page "Images" gallery on
# observations, names, locations, and users. Wraps the `Components::Carousel`
# primitive in a `Components::Panel` and registers per-image slides
# (`ImageGallery::Item`) + thumbnail indicators (`ImageGallery::Thumbnail`)
# via the carousel's `c.item(...) { … }` / `c.thumb(...) { … }` API.
#
# Replaces the legacy `Components::Carousel` (which inlined the Bootstrap
# carousel skeleton). The skeleton now lives in
# `Components::Carousel`; this component owns the Panel chrome,
# heading, no-images fallback, and the per-image render logic.
#
# @example
#   render Components::ImageGallery.new(
#     user: @user,
#     images: @images,
#     object: @observation,
#     title: "Observation Images",
#     thumbnails: true
#   )
class Components::ImageGallery < Components::Base
  # Nil entries are filtered at render time (`next unless image`),
  # so callers can mix nils in (e.g. a sparse Image[] from a query
  # that left some slots empty).
  prop :images, _Array(_Nilable(::Image)) do |value|
    value.respond_to?(:to_a) ? value.to_a : value
  end
  prop :user, _Nilable(::User)
  prop :object, _Nilable(::AbstractModel), default: nil
  prop :size, Components::Image::Base::Size, default: :large
  prop :title, ::String, default: -> { :IMAGES.t }
  prop :links, ::String, default: ""
  prop :thumbnails, _Boolean, default: true
  prop :carousel_id, _Nilable(::String), default: nil
  prop :panel_id, _Nilable(::String), default: nil

  def view_template
    @carousel_id ||= generate_carousel_id
    Panel(panel_id: @panel_id) do |panel|
      panel.with_heading { @title } if @thumbnails
      # `@links` is a `SafeBuffer` from a Rails `capture { … }` block;
      # in Phlex, slots that return a string escape it unless wrapped
      # in `trusted_html` (matches what Locations/User show-page
      # panels do).
      panel.with_heading_links { trusted_html(@links) } if @links.present?
      if @images&.any?
        panel.with_body(wrapper: false) { render_carousel }
      else
        render_no_images_message(panel)
      end
    end
  end

  private

  def generate_carousel_id
    type = @object&.type_tag || "image"
    object_id = @object&.id || "unknown"
    "#{type}_#{object_id}_carousel"
  end

  def render_carousel
    render(Components::Carousel.new(
             carousel_id: @carousel_id,
             wrapper_class: "show-carousel",
             show_controls: @images.compact.length > 1,
             show_indicators: @thumbnails
           )) do |c|
      register_slides(c)
      register_thumbnails(c) if @thumbnails
    end
  end

  def register_slides(carousel)
    @images.each do |image|
      next unless image

      carousel.item(id: "carousel_item_#{image.id}",
                    class: "carousel-item") do
        render(Components::ImageGallery::Item.new(
                 user: @user, image: image, object: @object, size: @size
               ))
      end
    end
  end

  def register_thumbnails(carousel)
    @images.each do |image|
      next unless image

      carousel.thumb(id: "carousel_thumbnail_#{image.id}",
                     data: { form_images_target: "thumbnail",
                             image_uuid: image.id,
                             image_status: "good" }) do
        render(Components::ImageGallery::Thumbnail.new(
                 user: @user, image: image
               ))
      end
    end
  end

  def render_no_images_message(panel)
    panel.with_thumbnail(
      classes: "p-4 my-5 w-100 h-100 text-center h3 text-muted"
    ) do
      plain(:show_observation_no_images.l)
    end
  end
end
