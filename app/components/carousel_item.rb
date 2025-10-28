# frozen_string_literal: true

# Individual carousel slide item component.
#
# Renders a single slide in a Bootstrap carousel with:
# - Large image with object-fit: contain
# - Stretched link overlay
# - Lightbox button
# - Carousel caption with votes and image info
#
# @example
#   render Components::CarouselItem.new(
#     user: current_user,
#     image: @image,
#     object: @observation,
#     index: 0
#   )
class Components::CarouselItem < Components::BaseImage
  # Additional carousel-specific properties
  prop :index, Integer, default: 0
  prop :object, _Nilable(Object), default: nil

  def initialize(index: 0, object: nil, **props)
    # Set carousel-specific defaults
    props[:size] ||= :large
    props[:fit] ||= :contain
    props[:original] ||= true
    props[:extra_classes] ||= "carousel-image"

    super
  end

  def view_template
    # Get image instance and ID
    img_instance, img_id = extract_image_and_id

    # Build render data
    render_data = build_render_data(img_instance, img_id)

    # Render the carousel item
    render_carousel_item(img_instance, img_id, render_data)
  end

  private

  def render_carousel_item(img_instance, img_id, data)
    div(
      id: "carousel_item_#{img_id}",
      class: build_item_classes
    ) do
      render_carousel_image(data)
      render_carousel_overlays(img_instance, data)
      render_carousel_caption(img_instance, data)
    end
  end

  def build_item_classes
    active = @index.zero? ? "active" : ""
    class_names("item carousel-item", active)
  end

  def render_carousel_image(data)
    img(
      src: data[:img_src],
      alt: @notes,
      class: data[:img_class],
      data: data[:img_data]
    )
  end

  def render_carousel_overlays(_img_instance, data)
    render_stretched_link(data[:image_link]) if @user && data[:image_link]
    render_lightbox_link(data[:lightbox_data]) if data[:lightbox_data]
  end

  def render_carousel_caption(img_instance, _data)
    caption_content = if img_instance && @object
                        image_info_html(img_instance, @object)
                      else
                        ""
                      end

    div(class: "carousel-caption") do
      # Vote section
      render_image_vote_section(img_instance)

      # Image info (copyright, notes)
      if caption_content.present?
        div(class: "image-info d-none d-sm-block") do
          raw(caption_content)
        end
      end
    end
  end

  def image_info_html(img_instance, obj)
    image_info(img_instance, obj, original: @original)
  end
end
