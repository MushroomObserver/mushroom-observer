# frozen_string_literal: true

module Images
  class ReuseController < ApplicationController
    before_action :login_required

    def serve_reuse_form(params)
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

    def look_for_image(method, params)
      return nil unless (method == "POST") || params[:img_id].present?

      unless (img = Image.safe_find(params[:img_id]))
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
      end
      img
    end

    def reuse_image_for_glossary_term
      pass_query_params
      @object = GlossaryTerm.safe_find(params[:id])
      image = look_for_image(request.method, params)
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

    # Browse through matrix of recent images to let a user reuse an image
    # they've already uploaded for another observation.
    # Linked from: observations/show and account/profile
    # Inputs:
    #   params[:mode]       "observation" or "profile"
    #   params[:obs_id]     (observation)
    #   params[:img_id]     (image)
    #   params[:all_users]  "0" or "1"
    # Outputs:
    #   @mode           :observation or :profile
    #   @all_users      true or false
    #   @pages          paginator for images
    #   @objects        Array of images
    #   @observation    observation (if in observation mode)
    #   @layout         layout parameters
    # Posts to the same action.  Redirects to show_observation or show_user.
    def reuse_image
      pass_query_params
      @mode = params[:mode].to_sym
      if @mode == :observation
        @observation = Observation.safe_find(params[:obs_id])
      end
      done = false

      # Make sure user owns the observation.
      if (@mode == :observation) &&
         !check_permission!(@observation)
        redirect_with_query(observation_path(id: @observation.id))
        done = true

      # User entered an image id by hand or clicked on an image.
      elsif (request.method == "POST") ||
            params[:img_id].present?
        image = Image.safe_find(params[:img_id])
        if !image
          flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
        elsif @mode == :observation
          # Add image to observation.
          @observation.add_image(image)
          image.log_reuse_for(@observation)
          if @observation.gps_hidden
            error = image.strip_gps!
            flash_error(:runtime_failed_to_strip_gps.t(msg: error)) if error
          end
          redirect_with_query(observation_path(id: @observation.id))
          done = true

        else
          # Change user's profile image.
          if @user.image == image
            flash_notice(:runtime_no_changes.t)
          else
            @user.update(image: image)
            flash_notice(:runtime_image_changed_your_image.t(id: image.id))
          end
          redirect_to(user_path(@user.id))
          done = true
        end
      end
      return if done

      # Serve form.
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
  end
end
