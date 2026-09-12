# frozen_string_literal: true

module Images
  class TransformationsController < ApplicationController
    before_action :login_required

    # Used by show_image to rotate and flip image. was GET. Currently a PUT
    def update
      image = find_or_goto_index(Image, params[:id].to_s)
      return unless image

      if authorized_to_transform?(image)
        transform_image_and_flash_notices(image)
      end

      # A full-page redirect tears down and re-subscribes the
      # turbo_stream_from([@image, :processed]) Action Cable
      # subscription on the show page -- if RotateImageJob's async
      # broadcast_processed_update fires during that reconnect gap,
      # the broadcast is dropped with no replay (#4854). Responding
      # with a flash-only turbo_stream instead keeps the existing
      # subscription alive, while still surfacing the flash notice
      # set above. Non-Turbo requests still redirect.
      respond_to do |format|
        format.turbo_stream { render(turbo_stream: turbo_stream_flash_update) }
        format.html { redirect_to(image_path(image)) }
      end
    end

    private

    # Broader than `permission!(image)`: also allows anyone who can
    # edit an Observation this image belongs to (project admin of the
    # observation's project, or the observation's collector), not just
    # the image's own owner/project. See Image#can_transform?, #4989.
    def authorized_to_transform?(image)
      return true if image.can_transform?(@user, site_admin: in_admin_mode?)

      flash_error(:permission_denied.l)
      false
    end

    def transform_image_and_flash_notices(image)
      case params[:op]
      when "rotate_left", "rotate_right", "mirror"
        image.transform(params[:op].to_sym)
        flash_notice(:image_show_transform_note.t)
      else
        flash_error(:runtime_invalid.t(type: '"operation"', value: params[:op]))
      end
    end
  end
end
