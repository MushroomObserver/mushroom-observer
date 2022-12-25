# frozen_string_literal: true

# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by thumbnail_helper#thumbnail(link: url_args)
# with CRUD refactor, change thumbnail helper to fire a POST somehow?

# No need to remove_images from Account profile: reuse_image removes image
module Account::Profile
  class ImagesController < ApplicationController
    before_action :login_required
    before_action :pass_query_params
    before_action :disable_link_prefetching

    # was reuse_image params[:mode] = profile
    def reuse
      return unless User.safe_find(params[:id]) == User.current
    end

    # POST action
    def attach
      return unless User.safe_find(params[:id]) == User.current

      image = Image.safe_find(params[:img_id])
      unless image
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
        redirect_to(:reuse) and return
      end

      attach_image_for_profile_and_flash_notice(image)
      redirect_to(user_path(@user.id))
    end

    # PUT action
    def detach
      if @user&.image
        @user.update(image: nil)
        flash_notice(:runtime_profile_removed_image.t)
      end
      redirect_to(user_path(@user.id))
    end

    private

    ############################################################################

    # The actual grid of images (partial) is basically a shared layout.
    # CRUD refactor could make each image link POST to create or delete.
    #
    # def serve_reuse_form(params)
    # params[:all_users] is a query param for rendering form images (possible
    # selections), not a form param for the submit.
    # It's toggled by a button on the page "Include other users' images"
    # that reloads the page with this param on or off
    # if params[:all_users] == "1"
    #   @all_users = true
    #   query = create_query(:Image, :all, by: :updated_at)
    # else
    #   query = create_query(:Image, :by_user, user: @user, by: :updated_at)
    # end
    # @layout = calc_layout_params
    # @pages = paginate_numbers(:page, @layout["count"])
    # @objects = query.paginate(@pages,
    #                           include: [:user, { observations: :name }])
    # end

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
