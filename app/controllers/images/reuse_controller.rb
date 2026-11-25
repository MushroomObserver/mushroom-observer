# frozen_string_literal: true

# Shared "attach an existing image" index, serving the observation /
# glossary_term / profile pages. `params[:target_type]`/
# `params[:target_id]` (query params on every request -- see
# config/routes.rb) pick the target; see TARGET_MODELS below. `index`
# is an index with interactions, same shape as
# `Observations::IdentifyController` -- the generic `build_index_with_
# query` machinery supplies the Image query/pagination. `update` is a
# RESTful member action on the image itself (`POST /images/:id/reuse`)
# that attaches `params[:id]`'s Image to the target.
module Images
  class ReuseController < ApplicationController
    before_action :login_required

    TARGET_MODELS = {
      "Observation" => ::Observation,
      "GlossaryTerm" => ::GlossaryTerm,
      "User" => ::User
    }.freeze

    def index
      return unless (@target = find_reuse_target!)
      return unless check_reuse_permission?
      return redirect_reflection_to_companion if reflection_target?

      force_index_filter_params
      build_index_with_query
    end

    # Per-thumbnail links and the id-entry form POST here.
    def update
      return unless (@target = find_reuse_target!)
      return unless check_attach_permission?
      return unless (@target = attach_target)

      image = Image.safe_find(params[:id])
      return render_invalid_image_id unless image

      attach_image_to_target(image)
    end

    def controller_model_name
      "Image"
    end

    private

    # `always_index: true` must win over whatever
    # `create_query_from_url_params` itself returns (it only forces
    # this on `?always_index=1`) -- a single reusable image must still
    # show the picker, not redirect to that image's show page.
    def index_display_opts(opts, _query)
      { grid: true, cache: false,
        include: [:user, { observations: :name }] }.
        merge(opts).
        merge(always_index: true)
    end

    def all_users?
      params[:all_users] == "1"
    end

    # Forcing `order_by` (rather than leaving it to pick up
    # `Query::Images`' own default) guarantees `other_filter_param_
    # present?` always takes the `create_query_from_url_params`
    # branch -- a fresh query every request, filtered by `by_user` or
    # not, instead of `sorted_index`'s session/bookmark-reusing
    # `find_or_create_query`.
    def force_index_filter_params
      params[:order_by] ||= "updated_at"
      params[:by_user] ||= @user.id.to_s unless all_users?
    end

    def find_reuse_target!
      return @user if params[:target_type] == "User"

      model = TARGET_MODELS[params[:target_type]]
      unless model
        head(:not_found)
        return nil
      end

      find_or_goto_index(model, params[:target_id].to_s)
    end

    def check_reuse_permission?
      return true unless params[:target_type] == "Observation"

      check_observation_permission?
    end

    def check_attach_permission?
      case params[:target_type]
      when "Observation" then check_observation_permission?
      when "User" then check_profile_permission?
      else true # GlossaryTerm: any logged-in user may edit
      end
    end

    def check_observation_permission?
      return true if permission!(@target)

      redirect_to(permanent_observation_path(id: @target.id))
      false
    end

    def check_profile_permission?
      return true if User.safe_find(params[:target_id]) == @user

      redirect_to(edit_account_profile_path)
      false
    end

    def render_index_view
      render(Views::Controllers::Images::Reuse::Index.new(
               target: @target, user: @user,
               pagination_data: @pagination_data, objects: @objects,
               all_users: all_users?
             ))
    end

    def render_invalid_image_id
      flash_error(:runtime_image_reuse_invalid_id.t(id: params[:id]))
      reload_and_render_invalid
    end

    def reload_and_render_invalid
      force_index_filter_params
      build_index_with_query
      self.status = :unprocessable_content
    end

    ############################################################################
    # Observation-specific reflection handling: a reflection's images
    # mirror its source (#4214), so reusing an image on one works on
    # its companion, as Edit does.

    def reflection_target?
      @target.is_a?(::Observation) && @target.reflection?
    end

    def redirect_reflection_to_companion
      companion = reflection_companion
      return unless companion

      redirect_to(images_reuse_path(target_type: "Observation",
                                    target_id: companion.id))
    end

    # The target an attach lands on: a reflection's companion, so the
    # chosen image isn't lost; nil after redirecting on failure.
    def attach_target
      return @target unless reflection_target?

      reflection_companion
    end

    # The reflection's companion, found or created, with a flash saying
    # which; nil after redirecting when it can't be created.
    def reflection_companion
      companion, notice = find_or_create_reuse_companion
      flash_notice(notice.t)
      companion
    rescue ActiveRecord::RecordInvalid => e
      flash_error(e.record.errors.full_messages.join("; "))
      redirect_to(permanent_observation_path(id: @target.id))
      nil
    end

    # [companion, flash tag]
    def find_or_create_reuse_companion
      builder = Observation::Companion.new(@target, @user,
                                           admin: in_admin_mode?)
      if (companion = builder.existing)
        [companion, :image_reuse_on_reflection_companion_existing]
      else
        [builder.create, :image_reuse_on_reflection_companion_created]
      end
    end

    ############################################################################
    # Attach dispatch per target type

    def attach_image_to_target(image)
      case params[:target_type]
      when "Observation" then attach_image_to_observation(image)
      when "GlossaryTerm" then attach_image_to_glossary_term(image)
      when "User" then attach_image_to_profile(image)
      end
    end

    def attach_image_to_observation(image)
      @target.add_image(image)
      image.current_user = @user
      image.log_reuse_for(@target)
      strip_gps_if_hidden(image)
      redirect_to(permanent_observation_path(id: @target.id))
    end

    def strip_gps_if_hidden(image)
      return unless @target.gps_hidden

      error = image.strip_gps!
      flash_error(:runtime_failed_to_strip_gps.t(msg: error)) if error
    end

    def attach_image_to_glossary_term(image)
      if @target.add_image(image) && @target.save
        image.current_user = @user
        image.log_reuse_for(@target)
        redirect_to(glossary_term_path(@target.id))
      else
        flash_error(:runtime_no_save.t(type: :glossary_term))
        reload_and_render_invalid
      end
    end

    def attach_image_to_profile(image)
      if @target.image == image
        flash_notice(:runtime_no_changes.t)
      else
        @target.update(image: image)
        flash_notice(:runtime_image_changed_your_image.t(id: image.id))
      end
      redirect_to(user_path(@target.id))
    end
  end
end
