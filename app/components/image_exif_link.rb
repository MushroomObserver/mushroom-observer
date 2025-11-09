# frozen_string_literal: true

# Component for rendering a link to view image EXIF data in a modal.
#
# @example Basic usage
#   render Components::ImageEXIFLink.new(
#     image_id: @image.id
#   )
#
# @example With custom CSS class
#   render Components::ImageEXIFLink.new(
#     image_id: @image.id,
#     link_class: "custom-link-class"
#   )
class Components::ImageEXIFLink < Components::Base
  prop :image_id, Integer, &:to_i
  prop :link_class, String, default: ""

  def view_template
    modal_link_to(
      "image_exif_#{@image_id}",
      :image_show_exif.t,
      exif_image_path(id: @image_id),
      { class: @link_class }
    )
  end
end
