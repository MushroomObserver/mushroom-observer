# frozen_string_literal: true

# Component for rendering a link to view the original image.
#
# @example Basic usage with an image instance
#   render Components::ImageOriginalLink.new(
#     image: @image
#   )
#
# @example With an image ID
#   render Components::ImageOriginalLink.new(
#     image_id: @image.id
#   )
#
# @example With custom CSS class
#   render Components::ImageOriginalLink.new(
#     image: @image,
#     link_class: "custom-link-class"
#   )
class Components::ImageOriginalLink < Components::Base
  include Phlex::Rails::Helpers::LinkTo

  prop :image, _Nilable(::Image), default: nil
  prop :image_id, _Nilable(Integer), default: nil
  prop :link_class, String, default: ""

  def view_template
    id = @image&.id || @image_id

    link_to(
      :image_show_original.t,
      "/images/#{id}/original",
      {
        class: @link_class,
        target: "_blank",
        rel: "noopener",
        data: {
          controller: "image-loader",
          action: "click->image-loader#load",
          "image-loader-target": "link",
          "loading-text": :image_show_original_loading.t,
          "maxed-out-text": :image_show_original_maxed_out.t,
          "error-text": :image_show_original_error.t
        }
      }
    )
  end
end
