# frozen_string_literal: true

# Component for rendering panel thumbnails.
#
# @example With block
#   render Components::PanelThumbnail.new do
#     image_tag("photo.jpg", class: "img-responsive")
#   end
class Components::PanelThumbnail < Components::Base
  def view_template
    div(class: "thumbnail-container") do
      yield if block_given?
    end
  end
end
