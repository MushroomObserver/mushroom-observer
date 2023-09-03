# frozen_string_literal: true

# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by ImageHelper#interactive_image(link: url_args)
# with CRUD refactor, change ImageHelper helper to fire a POST somehow?

# No need to remove_images from Account profile: reuse_image removes image
module Account::Profile
  class ImagesController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # was reuse_image params[:mode] = profile
    def reuse
      nil unless User.safe_find(params[:id]) == User.current
    end

    # POST action
    def attach
      return unless User.safe_find(params[:id]) == User.current

      image = Image.safe_find(params[:img_id])
      unless image
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
        render(:reuse, location: account_profile_select_image_path) and return
      end

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
