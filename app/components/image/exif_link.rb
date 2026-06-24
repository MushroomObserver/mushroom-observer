# frozen_string_literal: true

# Component for rendering a link to view image EXIF data in a modal.
#
# @example Basic usage
#   render Components::Image::EXIFLink.new(
#     image_id: @image.id
#   )
#
# @example With custom CSS class
#   render Components::Image::EXIFLink.new(
#     image_id: @image.id,
#     link_class: "custom-link-class"
#   )
class Components::Image::EXIFLink < Components::Base
  prop :image_id, Integer, &:to_i
  prop :link_class, String, default: ""

  def view_template
    render(Components::Button.new(
             type: :modal,
             name: :image_show_exif.t,
             target: exif_image_path(id: @image_id),
             modal_id: "image_exif_#{@image_id}",
             variant: :strip, class: @link_class
           ))
  end
end
