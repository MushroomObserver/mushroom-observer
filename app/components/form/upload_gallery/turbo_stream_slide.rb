# frozen_string_literal: true

# Single-slide wrapper for the upload turbo_stream path. When the user
# adds an image to the obs form, `Observations::Images::UploadsController#new`
# turbo_stream-prepends a slide to `#added_images` and a thumbnail to
# `#added_thumbnails`. In the gallery's `view_template`, the slide's
# `<div class="item carousel-item active" data-…>` wrapper is emitted
# by the shared `Components::Carousel` primitive's `c.item(...)`; from a
# turbo_stream there's no primitive context, so this thin component
# reproduces the same wrapper-shape around `UploadGallery::Item`.
class Components::Form::UploadGallery::TurboStreamSlide < Components::Base
  prop :user, _Nilable(::User), default: nil
  prop :image, _Nilable(::Image), default: nil
  prop :img_id, ::String
  prop :file_name, _Nilable(::String), default: nil
  prop :file_size, _Nilable(::String), default: nil

  def view_template
    div(id: "carousel_item_#{@img_id}",
        class: "item carousel-item active",
        data: {
          form_images_target: "item",
          form_exif_target: "item",
          action: "form-exif:populated->form-images#itemExifPopulated",
          image_uuid: @img_id,
          image_status: "upload"
        }) do
      render(Components::Form::UploadGallery::Item.new(
               user: @user,
               image: @image,
               img_id: @img_id,
               upload: true,
               obs_thumb_id: nil,
               camera_info: { file_name: @file_name, file_size: @file_size }
             ))
    end
  end
end
