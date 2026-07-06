# frozen_string_literal: true

module Observations::Images
  class UploadsController < ApplicationController
    before_action :login_required

    layout false

    # Uploading images for an observation is a multi-stage thing.
    # First, each selected image with its EXIF data is read and displayed in
    # the create obs form, where the user can reconcile dates and locations
    # with the obs.
    # This action returns formatted HTML (upload image template) for one image
    # to the Stimulus form-images_controller. This is added to the page
    # when uploading multiple images on create observation. Returns two
    # turbo_stream actions: prepend a `Form::UploadGallery::TurboStreamSlide`
    # to `#added_images` and a `Form::UploadGallery::TurboStreamThumb` to
    # `#added_thumbnails`. (The wrapper components reproduce the
    # `<div class="item">` / `<li class="carousel-indicator">` shapes that
    # `Components::Carousel`'s `c.item(...)` / `c.thumb(...)` registration
    # owns inline — needed for the turbo_stream insertion path because
    # there's no primitive context there.)
    # was multi_image_template
    def new
      @licenses = License.available_names_and_ids(@user.license)
      @image = Image.new(user: @user, when: Time.zone.now,
                         copyright_holder: @user.legal_name)
      render(turbo_stream: [
               prepend_form_carousel_item, prepend_carousel_thumbnail
             ])
    end

    # Uploads an image object without an observation.
    # Returns image as JSON object.
    # was create_image_object
    # Because this is a POST, requires auth token
    def create
      args = params[:image]
      image = create_and_upload_image(args)
      render_image(image, args)
    rescue StandardError => e
      render_errors(e.to_s, args)
    end

    private

    def prepend_form_carousel_item
      turbo_stream.prepend(
        "added_images",
        ::Components::Form::UploadGallery::TurboStreamSlide.new(
          user: @user, image: @image,
          img_id: params[:img_id],
          file_name: params[:file_name],
          file_size: params[:file_size]
        )
      )
    end

    def prepend_carousel_thumbnail
      turbo_stream.prepend(
        "added_thumbnails",
        ::Components::Form::UploadGallery::TurboStreamThumb.new(
          user: @user, image: @image, img_id: params[:img_id]
        )
      )
    end

    def render_image(image, args)
      name = args[:original_name].to_s
      flash_notice(:runtime_image_uploaded.t(name: name))
      render(json: image)
    end

    def render_errors(errors, args)
      name = args[:original_name].to_s
      errors += "\n#{:runtime_no_upload_image.t(name: name)}"
      logger.error("UPLOAD_FAILED: #{errors.inspect}")
      render(plain: errors.strip_html, status: :internal_server_error)
    end

    def create_and_upload_image(args)
      image = create_image(args)
      upload_image(image, args)
      return image if image.save && image.process_image

      raise(image.formatted_errors.join("\n"))
    ensure
      image.try(&:clean_up)
    end

    def create_image(args)
      Image.new(
        created_at: Time.zone.now,
        user: @user,
        when: image_date(args),
        license_id: args[:license].to_i,
        notes: args[:notes].to_s,
        copyright_holder: args[:copyright_holder].to_s,
        original_name: image_original_name(args)
      )
    end

    def upload_image(image, args)
      if args[:url].blank?
        image.image = args[:upload]
      else
        image.upload_from_url(args[:url])
      end
    end

    def image_original_name(args)
      return nil if @user.keep_filenames == "toss"

      args[:original_name].to_s
    end

    def image_date(args)
      # TODO: handle invalid date
      hash = args[:when] || {}
      Date.new(hash["1i"].to_i,
               hash["2i"].to_i,
               hash["3i"].to_i)
    end
  end
end
