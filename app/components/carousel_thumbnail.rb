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
#     carousel_id: "observation_123_carousel"
#   )
class Components::CarouselThumbnail < Components::BaseImage
  # Additional thumbnail-specific properties
  prop :index, Integer, default: 0
  prop :carousel_id, String

  def initialize(carousel_id:, index: 0, img_id: nil, **props)
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
    @img_instance, @img_id = extract_image_and_id

    # For uploads, use fallback if no ID
    @img_id ||= "img_id_missing"

    # Ensure img_id is not an Image object (convert to integer if needed)
    @img_id = @img_id.id if @img_id.is_a?(::Image)

    # Build render data
    @data = build_render_data(@img_instance, @img_id)

    # Render the thumbnail
    render_thumbnail
  end

  private

  def render_thumbnail
    active = @index.zero? ? "active" : ""
    image_status = @upload ? "upload" : "good"

    li(
      id: "carousel_thumbnail_#{@img_id}",
      class: ["carousel-indicator mx-1", active],
      data: {
        target: "##{@carousel_id}",
        slide_to: @index.to_s,
        form_images_target: "thumbnail",
        image_uuid: @img_id,
        image_status: image_status
      }
    ) do
      img(
        src: @data[:img_src],
        alt: @notes,
        class: @data[:img_class],
        data: @data[:img_data]
      )
    end
  end
end
