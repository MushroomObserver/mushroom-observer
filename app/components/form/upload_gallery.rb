# frozen_string_literal: true

# Editable image-upload carousel — the observation form's image-upload
# section. Wraps the `Components::Carousel` primitive in form-specific
# chrome (Stimulus targets for `form_images` / `form_exif`, a wrapped
# controls strip, and `d-none` toggle on the indicator list when there's
# only one image) and registers per-image slides + thumbnails via the
# carousel's `c.item(...) { … }` / `c.thumb(...) { … }` API.
#
# @example
#   render Components::Form::UploadGallery.new(
#     user: @user,
#     images: @good_images,
#     obs_thumb_id: @observation.thumb_image_id,
#     exif_data: @exif_data
#   )
class Components::Form::UploadGallery < Components::Base
  prop :images, _Nilable(_Array(::Image)), default: nil
  prop :sibling_images, _Array(::Image), default: -> { [] }
  prop :user, _Nilable(::User)
  prop :carousel_id, ::String,
       default: "observation_upload_images_carousel"
  prop :obs_thumb_id, _Nilable(::Integer), default: nil
  # `{ image_id => exif_hash }`. Inner hash is camera/EXIF metadata
  # (strings / nils); validated as a plain Hash so callers aren't
  # locked into a specific key/value shape.
  prop :exif_data, _Hash(::Integer, ::Hash), default: -> { {} }

  def view_template
    Carousel(
      carousel_id: @carousel_id,
      wrapper_class: "image-form-carousel",
      inner_id: "added_images",
      indicators_id: "added_thumbnails",
      indicators_class_extra: indicators_d_none,
      controls_wrap_class: "carousel-control-wrap row",
      extra_data: {
        form_images_target: "carousel",
        form_exif_target: "carousel"
      }
    ) do |c|
      register_slides(c)
      register_thumbnails(c)
    end
  end

  private

  def total_image_count
    (@images&.length || 0) + @sibling_images.length
  end

  def indicators_d_none
    total_image_count <= 1 ? "d-none" : ""
  end

  def register_slides(carousel)
    register_upload_slides(carousel)
    register_sibling_slides(carousel)
  end

  def register_upload_slides(carousel)
    @images&.each do |image|
      register_upload_slide(carousel, image)
    end
  end

  def register_upload_slide(carousel, image)
    img_id_for_dom = image&.id || "img_id_missing"
    upload = image&.created_at.nil?
    carousel.item(id: "carousel_item_#{img_id_for_dom}",
                  class: "carousel-item",
                  data: upload_slide_data(image, upload)) do
      render(Components::Form::UploadGallery::Item.new(
               user: @user,
               image: image,
               upload: upload,
               obs_thumb_id: @obs_thumb_id,
               camera_info: @exif_data[image&.id] || {}
             ))
    end
  end

  # Matches the legacy `data: { … geocode: @camera_info.to_json unless
  # @upload }` pattern: geocode only emitted for non-upload slides; an
  # `{}` exif hash still serializes to "{}".
  def upload_slide_data(image, upload)
    img_id_for_dom = image&.id || "img_id_missing"
    status = upload ? "upload" : "good"
    data = {
      form_images_target: "item",
      form_exif_target: "item",
      action: "form-exif:populated->form-images#itemExifPopulated",
      image_uuid: img_id_for_dom,
      image_status: status
    }
    data[:geocode] = (@exif_data[image&.id] || {}).to_json unless upload
    data
  end

  def register_sibling_slides(carousel)
    @sibling_images.each do |image|
      register_sibling_slide(carousel, image)
    end
  end

  def register_sibling_slide(carousel, image)
    img_id_for_dom = image&.id || "img_id_missing"
    carousel.item(id: "carousel_item_#{img_id_for_dom}",
                  class: "carousel-item",
                  data: sibling_slide_data(image)) do
      render(Components::Form::UploadGallery::Item.new(
               user: @user,
               image: image,
               upload: false,
               obs_thumb_id: @obs_thumb_id,
               camera_info: {},
               sibling: true
             ))
    end
  end

  def sibling_slide_data(image)
    img_id_for_dom = image&.id || "img_id_missing"
    # `image_status: "good"` — sibling slides are pre-existing images
    # too (just from another observation, hence not editable here).
    # `form-images_controller.js#itemTargetConnected` returns early on
    # "good" / "upload"; anything else logs an error and skips. The
    # sibling-specific UI differences are gated by the `sibling: true`
    # prop on `Components::Form::UploadGallery::Item`, not by the
    # status string.
    {
      form_images_target: "item",
      form_exif_target: "item",
      action: "form-exif:populated->form-images#itemExifPopulated",
      image_uuid: img_id_for_dom,
      image_status: "good",
      geocode: "{}"
    }
  end

  def register_thumbnails(carousel)
    register_upload_thumbnails(carousel)
    register_sibling_thumbnails(carousel)
  end

  def register_upload_thumbnails(carousel)
    @images&.each do |image|
      register_thumbnail(carousel, image, status: thumb_status(image))
    end
  end

  def register_sibling_thumbnails(carousel)
    @sibling_images.each do |image|
      register_thumbnail(carousel, image, status: "good")
    end
  end

  def register_thumbnail(carousel, image, status:)
    img_id_for_dom = image&.id || "img_id_missing"
    carousel.thumb(id: "carousel_thumbnail_#{img_id_for_dom}",
                   data: { form_images_target: "thumbnail",
                           image_uuid: img_id_for_dom,
                           image_status: status }) do
      render(Components::ImageGallery::Thumbnail.new(
               user: @user, image: image, upload: image&.created_at.nil?
             ))
    end
  end

  def thumb_status(image)
    image&.created_at.nil? ? "upload" : "good"
  end
end
