# frozen_string_literal: true

# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by Components::Image::Interactive(link: url_args)
# with CRUD refactor, change component link to fire a POST somehow?

# No need to remove_images from Account profile: reuse_image removes image
module Account::Profile
  class ImagesController < ApplicationController
    include ::ImageReusable

    before_action :login_required

    # was reuse_image params[:mode] = profile
    def reuse
      load_images_to_reuse
      render(Views::Controllers::Account::Profile::Images::Reuse.new(
               user: @user,
               objects: @reuse_images,
               pagination_data: @reuse_pagination,
               all_users: @reuse_all_users
             ))
    end

    # POST action
    def attach
      return unless User.safe_find(params[:id]) == @user

      @img_id = params.dig(:image_reuse, :img_id).presence || params[:img_id]
      image = Image.safe_find(@img_id)
      return render_reuse_with_invalid_id_error unless image

      attach_image_for_profile_and_flash_notice(image)
      redirect_to(user_path(@user.id))
    end

    # PUT action. Does not require a param, just removes user.image_id
    def detach
      if @user&.image
        @user.update(image: nil)
        flash_notice(:runtime_profile_removed_image.t)
      end
      redirect_to(edit_account_profile_path)
    end

    private

    ############################################################################

    # The actual grid of images (partial) is a shared layout.
    # CRUD refactor could make each image link POST to create or delete.

    def render_reuse_with_invalid_id_error
      flash_error(:runtime_image_reuse_invalid_id.t(id: @img_id))
      load_images_to_reuse
      render(Views::Controllers::Account::Profile::Images::Reuse.new(
               user: @user, objects: @reuse_images,
               pagination_data: @reuse_pagination,
               all_users: @reuse_all_users
             ), location: account_profile_select_image_path)
    end

    def attach_image_for_profile_and_flash_notice(image)
      # Change user's profile image.
      if @user.image == image
        flash_notice(:runtime_no_changes.t)
      else
        @user.update(image: image)
        flash_notice(:runtime_image_changed_your_image.t(id: image.id))
      end
    end
  end
end
