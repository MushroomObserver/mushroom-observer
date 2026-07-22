# frozen_string_literal: true

module Images
  class TransformationsController < ApplicationController
    before_action :login_required

    # Used by show_image to rotate and flip image. was GET. Currently a PUT
    def update
      image = find_or_goto_index(Image, params[:id].to_s)
      return unless image

      transform_image_and_flash_notices(image) if permission!(image)

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

    def transform_image_and_flash_notices(image)
      case params[:op]
      when "rotate_left", "rotate_right", "mirror"
        image.transform(params[:op].to_sym)
        flash_notice(:image_show_transform_note.t)
      else
        flash_error("Invalid operation #{params[:op].inspect}")
      end
    end
  end
end
