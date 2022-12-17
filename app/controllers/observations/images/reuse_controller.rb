# frozen_string_literal: true

# NOTE: The reuse_image and remove_image actions have specialized controls
# for each potential object they're attached to.
# They also seem like they'd be more at home if moved to new controllers:
# Account::Images::ReuseController#new #create
# Observations::Images::ReuseController#new #create
# GlossaryTerms::Images::ReuseController#new #create
# Move tests from images_controller_test
#
# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by thumbnail_helper#thumbnail(link: url_args)
# with CRUD refactor, maybe change that to fire a POST somehow?

module Observations::Images
  class ReuseController < ApplicationController
    before_action :login_required
    before_action :pass_query_params
    before_action :disable_link_prefetching

    def new # reuse_image params[:mode] = observation
      # Stop right here if they're trying to add an image to obs w/o permission
      @observation = Observation.safe_find(params[:obs_id])
      # check_observation_permission! plus return
      unless check_permission!(@observation)
        return redirect_with_query(
          permanent_observation_path(id: @observation.id)
        )
      end

      serve_reuse_form(params)
    end

    def create
      # Stop right here if they're trying to add an image to obs w/o permission
      @observation = Observation.safe_find(params[:obs_id])
      # check_observation_permission! plus return
      unless check_permission!(@observation)
        return redirect_with_query(
          permanent_observation_path(id: @observation.id)
        )
      end

      image = Image.safe_find(params[:img_id])
      unless image
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
        return serve_reuse_form(params)
      end

      reuse_image_for_observation(image)
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

      # These could be set (except @objects) on shared layout
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

    def reuse_image_for_observation(image)
      # Add image to observation.
      @observation.add_image(image)
      image.log_reuse_for(@observation)
      if @observation.gps_hidden
        error = image.strip_gps!
        flash_error(:runtime_failed_to_strip_gps.t(msg: error)) if error
      end
      redirect_with_query(permanent_observation_path(id: @observation.id))
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
