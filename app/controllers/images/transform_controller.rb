# frozen_string_literal: true

module Images
  class TransformController < ApplicationController
    before_action :login_required

    # Used by show_image to rotate and flip image.
    def transform_image
      pass_query_params
      image = find_or_goto_index(Image, params[:id].to_s)
      return unless image

      if check_permission!(image)
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
      if params[:size].blank? ||
         params[:size].to_sym == (@user ? @user.image_size.to_sym : :medium)
        redirect_with_query(action: "show_image", id: image)
      else
        redirect_with_query(action: "show_image", id: image,
                            size: params[:size])
      end
    end
  end
end
