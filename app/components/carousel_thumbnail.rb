# frozen_string_literal: true

# Carousel thumbnail navigation item component.
#
# Renders a thumbnail indicator for carousel navigation.
# Handles both uploaded images (no Image record) and existing images.
#
# @example
#   render Components::CarouselThumbnail.new(
#     user: current_user,
#     image: @image,
#     index: 0,
#     html_id: "observation_123_carousel"
#   )
class Components::CarouselThumbnail < Components::BaseImage
  # Additional thumbnail-specific properties
  prop :index, Integer, default: 0
  prop :html_id, String
  prop :img_id, _Nilable(Integer), default: nil do |value|
    value&.to_i
  end

  def initialize(html_id:, index: 0, img_id: nil, **props)
    # Set thumbnail-specific defaults
    props[:size] ||= :thumbnail
    props[:fit] ||= :contain

    # Add carousel-thumbnail class
    base_classes = "carousel-thumbnail"
    base_classes += " set-src" if props[:upload]
    props[:extra_classes] =
      [props[:extra_classes], base_classes].compact.join(" ")

    super
  end

  def view_template
    # Get image instance and ID
    img_instance, final_img_id = extract_image_and_id

    # For uploads, use provided img_id or fallback
    final_img_id = @img_id || final_img_id || "img_id_missing"

    # Build render data
    render_data = build_render_data(img_instance, final_img_id)

    # Render the thumbnail
    render_thumbnail(final_img_id, render_data)
  end

  private

  def render_thumbnail(final_img_id, data)
    active = @index.zero? ? "active" : ""
    image_status = @upload ? "upload" : "good"

    li(
      id: "carousel_thumbnail_#{final_img_id}",
      class: ["carousel-indicator mx-1", active],
      data: {
        target: "##{@html_id}",
        slide_to: @index.to_s,
        form_images_target: "thumbnail",
        image_uuid: final_img_id,
        image_status: image_status
      }
    ) do
      img(
        src: data[:img_src],
        alt: @notes,
        class: data[:img_class],
        data: data[:img_data]
      )
    end
  end
end
