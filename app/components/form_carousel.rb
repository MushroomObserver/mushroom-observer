# frozen_string_literal: true

# Form carousel component for uploading and editing observation images.
#
# This carousel is used in observation forms to display and manage images.
# It includes form fields for each image and EXIF camera metadata display.
#
# @example
#   render Components::FormCarousel.new(
#     user: current_user,
#     images: @good_images,
#     obs_thumb_id: @observation.thumb_image_id,
#     exif_data: @exif_data
#   )
class Components::FormCarousel < Components::Base
  include Phlex::Rails::Helpers::LinkTo

  # Properties
  prop :images, _Nilable(Array), default: nil
  prop :user, _Nilable(User)
  prop :carousel_id, String, default: "observation_upload_images_carousel"
  prop :obs_thumb_id, _Nilable(Integer), default: nil
  prop :exif_data, Hash, default: -> { {} }

  def view_template
    div(
      id: @carousel_id,
      class: "carousel slide image-form-carousel",
      data: {
        ride: "false",
        interval: "false",
        form_images_target: "carousel",
        form_exif_target: "carousel"
      }
    ) do
      # Carousel inner (slides with form fields)
      div(
        id: "added_images",
        class: "carousel-inner bg-light",
        role: "listbox"
      ) do
        render_carousel_items

        # Carousel controls
        div(class: "carousel-control-wrap row") do
          CarouselControls(carousel_id: @carousel_id)
        end
      end

      # Thumbnail navigation
      ol(
        id: "added_thumbnails",
        class: "carousel-indicators panel-footer py-2 px-0 mb-0"
      ) do
        render_thumbnails
      end
    end
  end

  private

  def render_carousel_items
    @images&.each_with_index do |image, index|
      upload = image&.created_at.nil?

      FormCarouselItem(
        user: @user,
        image: image,
        index: index,
        upload: upload,
        obs_thumb_id: @obs_thumb_id,
        camera_info: @exif_data[image&.id] || {}
      )
    end
  end

  def render_thumbnails
    @images&.each_with_index do |image, index|
      CarouselThumbnail(
        user: @user,
        image: image,
        index: index,
        carousel_id: @carousel_id
      )
    end
  end
end
