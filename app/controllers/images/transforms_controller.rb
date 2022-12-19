# frozen_string_literal: true

module Images
  class TransformsController < ApplicationController
    before_action :login_required

    # Used by show_image to rotate and flip image. Currently GET
    def create
      pass_query_params
      image = find_or_goto_index(Image, params[:id].to_s)
      return unless image

      transform_image_and_flash_notices(image) if check_permission!(image)

      # NOTE: 2022/12 params[:size] is unused in show_image
      redirect_with_query(show_image_path(image))
    end

    def transform_image_and_flash_notices(image)
      case params[:op]
      when "rotate_left"
        image.transform(:rotate_left)
        flash_notice(:image_show_transform_note.t)
      when "rotate_right"
        image.transform(:rotate_right)
        flash_notice(:image_show_transform_note.t)
      when "mirror"
        image.transform(:mirror)
        flash_notice(:image_show_transform_note.t)
      else
        flash_error("Invalid operation #{params[:op].inspect}")
      end
    end
  end
end
