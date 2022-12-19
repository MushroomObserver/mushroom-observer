# frozen_string_literal: true

# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by thumbnail_helper#thumbnail(link: url_args)
# with CRUD refactor, change thumbnail helper to fire a POST somehow?

module Observations
  class ImagesController < ApplicationController
    before_action :login_required
    before_action :pass_query_params
    before_action :disable_link_prefetching

    # reuse_image params[:mode] = observation
    def new
      @observation = Observation.safe_find(params[:id])
      # Stop right here if they're trying to add an image to obs w/o permission
      unless check_permission!(@observation)
        return redirect_with_query(
          permanent_observation_path(id: @observation.id)
        )
      end

      serve_image_reuse_selections(params)
    end

    def create
      @observation = Observation.safe_find(params[:id])
      # Stop right here if they're trying to add an image to obs w/o permission
      unless check_permission!(@observation)
        return redirect_with_query(
          permanent_observation_path(id: @observation.id)
        )
      end

      image = Image.safe_find(params[:img_id])
      unless image
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
        return serve_image_reuse_selections(params)
      end

      reuse_image_for_observation(image)
    end

    private

    ############################################################################

    # The actual grid of images (partial) is a shared layout.
    # CRUD refactor, each image has a link that POSTs to :create.
    #
    def serve_image_reuse_selections(params)
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

    # Add an image to observation.
    def reuse_image_for_observation(image)
      @observation.add_image(image)
      image.log_reuse_for(@observation)
      if @observation.gps_hidden
        error = image.strip_gps!
        flash_error(:runtime_failed_to_strip_gps.t(msg: error)) if error
      end
      redirect_with_query(permanent_observation_path(id: @observation.id))
    end

    public

    ############################################################################

    # REMOVE IMAGES: Maybe use shared form (but there's nothing to the "form")
    # Form used to remove one or more images from an observation (not destroy!)
    # Linked from: observations/show
    # Inputs:
    #   params[:obj_id]              (observation)
    #   params[:selected][image_id]  (value of "yes" means remove)
    # Outputs: @observation
    # Redirects to observations/show.
    # remove_images
    def edit
      @object = find_or_goto_index(Observation, params[:id].to_s)
      return unless @object

      return unless check_permission!(@object)

      redirect_with_query(permanent_observation_path(@object.id))
    end

    def update
      @object = find_or_goto_index(Observation, params[:id].to_s)
      return unless @object

      unless check_permission!(@object)
        return redirect_with_query(permanent_observation_path(@object.id))
      end
      return unless (images = params[:selected])

      remove_images_from_object(images)
    end

    ############################################################################

    private

    def remove_images_from_object(images)
      images.each do |image_id, do_it|
        next unless do_it == "yes"

        next unless (image = Image.safe_find(image_id))

        @object.remove_image(image)
        image.log_remove_from(@object)
        flash_notice(:runtime_image_remove_success.t(id: image_id))
      end
      redirect_with_query(permanent_observation_path(@object.id))
    end
  end
end
