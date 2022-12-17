# frozen_string_literal: true

# NOTE: Move to new namespaced controllers
#
# Observations::Images::ReuseController#edit #update
# GlossaryTerms::Images::ReuseController#edit #update
# Account::Profile::ImagesController#edit #update
# Move tests from images_controller_test
# No need to remove_images from Account profile: reuse_image removes image

module GlossaryTerms::Images
  class ReuseController < ApplicationController
    before_action :login_required

    before_action :login_required
    before_action :pass_query_params
    before_action :disable_link_prefetching

    def new # reuse_image params[:mode] = observation
      # Stop right here if they're trying to add an image to obs w/o permission
      @observation = GlossaryTerm.safe_find(params[:obs_id])
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
      @observation = GlossaryTerm.safe_find(params[:obs_id])
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

      reuse_image_for_glossary_term(image)
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

    def reuse_image_for_glossary_term(image = nil)
      @object = GlossaryTerm.safe_find(params[:id])
      image ||= look_for_image(request.method, params)
      if image &&
         @object.add_image(image) &&
         @object.save
        image.log_reuse_for(@object)
        redirect_with_query(glossary_term_path(@object.id))
      else
        flash_error(:runtime_no_save.t(:glossary_term)) if image
        serve_reuse_form(params)
      end
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
