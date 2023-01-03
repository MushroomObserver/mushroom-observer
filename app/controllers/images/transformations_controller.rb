# frozen_string_literal: true

module Images
  class TransformationsController < ApplicationController
    before_action :login_required

    # Used by show_image to rotate and flip image. was GET. Currently a PUT
    def update
      pass_query_params
      image = find_or_goto_index(Image, params[:id].to_s)
      return unless image

      transform_image_and_flash_notices(image) if check_permission!(image)

      # NOTE: 2022/12 params[:size] is unused in show_image
      redirect_with_query(image_path(image))
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
