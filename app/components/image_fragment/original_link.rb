# frozen_string_literal: true

# Component for rendering a link to view the original image.
#
# @example Basic usage with an image instance
#   ImageFragment(type: :original_link, image: @image)
#
# @example With an image ID
#   ImageFragment(type: :original_link, image_id: @image.id)
#
# @example With custom CSS class
#   ImageFragment(type: :original_link, image: @image,
#                 link_class: "custom-link-class")
class Components::ImageFragment::OriginalLink < Components::Base
  prop :image, _Nilable(::Image), default: nil
  prop :image_id, _Nilable(Integer), default: nil
  prop :link_class, String, default: ""

  def view_template
    id = @image&.id || @image_id

    Link(type: :get,
         name: :image_show_original.l,
         target: "/images/#{id}/original",
         new_tab: true,
         class: @link_class,
         data: {
           controller: "image-loader",
           action: "click->image-loader#load",
           "image-loader-target": "link",
           "loading-text": :image_show_original_loading.l,
           "maxed-out-text": :image_show_original_maxed_out.l,
           "error-text": :image_show_original_error.l
         })
  end
end
