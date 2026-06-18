# frozen_string_literal: true

# Single-thumbnail wrapper for the upload turbo_stream path —
# sibling of `Components::Form::UploadGallery::TurboStreamSlide`.
# Emits the `<li class="carousel-indicator">` wrapper around an
# `ImageGallery::Thumbnail` so the turbo_stream prepend lands
# correctly inside `#added_thumbnails`.
class Components::Form::UploadGallery::TurboStreamThumb < Components::Base
  prop :user, _Nilable(::User), default: nil
  prop :image, _Nilable(::Image), default: nil
  prop :img_id, ::String

  CAROUSEL_ID = "observation_upload_images_carousel"

  def view_template
    li(id: "carousel_thumbnail_#{@img_id}",
       class: "carousel-indicator mx-1",
       data: {
         target: "##{CAROUSEL_ID}",
         slide_to: "0",
         form_images_target: "thumbnail",
         image_uuid: @img_id,
         image_status: "upload"
       }) do
      render(Components::ImageGallery::Thumbnail.new(
               user: @user, image: @image, upload: true
             ))
    end
  end
end
