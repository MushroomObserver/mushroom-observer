# frozen_string_literal: true

# NOTE: Move to new namespaced controllers
#
# Account::Profile::ImagesController#edit #update
# Move tests from images_controller_test
# No need to remove_images from Account profile: reuse_image removes image

module Account::Profile
  class ImagesController < ApplicationController
    before_action :login_required
    before_action :pass_query_params
    before_action :disable_link_prefetching

    # reuse_image params[:mode] = profile
    def new
      return unless User.safe_find(params[:obj_id]) == User.current

      serve_reuse_form(params)
    end

    def create
      return unless User.safe_find(params[:obj_id]) == User.current

      image = Image.safe_find(params[:img_id])
      unless image
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
        return serve_reuse_form(params)
      end

      attach_image_for_profile(image)
    end

    private

    ############################################################################

    # The actual grid of images (partial) is basically a shared layout.
    # CRUD refactor could make each image link POST to create or delete.
    #
    def serve_reuse_form(params)
      # params[:all_users] is a query param for rendering form images (possible
      # selections), not a form param for the submit.
      # It's toggled by a button on the page "Include other users' images"
      # that reloads the page with this param on or off
      if params[:all_users] == "1"
        @all_users = true
        query = create_query(:Image, :all, by: :updated_at)
      else
        query = create_query(:Image, :by_user, user: @user, by: :updated_at)
      end
      @layout = calc_layout_params
      @pages = paginate_numbers(:page, @layout["count"])
      @objects = query.paginate(@pages,
                                include: [:user, { observations: :name }])
    end

    def attach_image_for_profile(image)
      # Change user's profile image.
      if @user.image == image
        flash_notice(:runtime_no_changes.t)
      else
        @user.update(image: image)
        flash_notice(:runtime_image_changed_your_image.t(id: image.id))
      end
      redirect_to(user_path(@user.id))
    end

    def look_for_image(method, params)
      return nil unless (method == "POST") || params[:img_id].present?

      unless (img = Image.safe_find(params[:img_id]))
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
      end
      img
    end
  end
end
