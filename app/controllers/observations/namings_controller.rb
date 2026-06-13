# frozen_string_literal: true

# Controller for handling the naming of observations

module Observations
  class NamingsController < ApplicationController # rubocop:disable Metrics/ClassLength
    include ObservationsController::Validators

    before_action :login_required

    # Bullet wants us to eager load interests on taxa, which is loaded in
    # Naming#create_emails
    around_action :skip_bullet, if: -> { defined?(Bullet) },
                                only: [:create, :update]

    # The route for the namings table, an index of this obs' namings.
    # The view derives `consensus` from `observation` internally.
    def index
      @observation = find_or_goto_index(Observation, params[:observation_id])
      return unless @observation

      render(Views::Controllers::Observations::Namings::Index.new(
               observation: @observation, user: @user
             ))
    end

    # Note that every Naming form is also a nested Vote form.
    def new
      init_ivars
      return unless @observation

      respond_to do |format|
        format.turbo_stream { render_modal_naming_form }
        format.html { render_phlex_new }
      end
    end

    # Note that the `respond_to_successful_` actions do reload the associations
    # after the save/update. Maybe naming_includes are enough here?
    #
    def create
      init_ivars
      return unless @observation

      @consensus = Observation::NamingConsensus.new(@observation)

      if rough_draft && can_save?
        save_changes
        respond_to_successful_create
      else # If anything failed reload the form.
        flash_naming_errors
        add_reasons(params.dig(:naming, :reasons))
        respond_to_form_errors
      end
    end

    def edit
      init_ivars
      @observation = Observation.show_includes.find(params[:observation_id])
      @naming = naming_from_params
      # N+1: What is this doing? Watch out for permission!
      return redirect_to_obs(@observation) unless permission!(@naming)

      init_edit_ivars
      @consensus = Observation::NamingConsensus.new(@observation)
      @vote = @consensus.users_vote(@naming, @user)

      respond_to do |format|
        format.turbo_stream { render_modal_naming_form }
        format.html { render_phlex_edit }
      end
    end

    def update
      init_ivars
      @observation = Observation.show_includes.find(params[:observation_id])
      @naming = naming_from_params
      # N+1: What is this doing? Watch out for permission!
      return redirect_to_obs(@observation) unless permission!(@naming)

      @consensus = Observation::NamingConsensus.new(@observation)
      @vote = @consensus.users_vote(@naming, @user)

      if can_update?
        need_new_naming? ? create_new_naming : change_naming
        redirect_to_obs(@observation)
      else
        add_reasons(params.dig(:naming, :reasons))
        respond_to_form_errors
      end
    end

    def destroy
      naming = Naming.show_includes.find(params[:id].to_s)
      @observation = Observation.naming_includes.find(params[:observation_id])
      @consensus = Observation::NamingConsensus.new(@observation)
      if destroy_if_we_can(naming) # needs to know consensus before deleting
        flash_notice(:runtime_destroy_naming_success.t(id: params[:id].to_s))
      end

      redirect_to_obs(@observation)
    end

    #########

    private

    def init_ivars
      @naming = Naming.new
      @vote = Vote.new
      # @given_name can't be nil else rails tries to call @name.name
      @given_name = params[:naming].to_s
      @reasons = @naming.init_reasons
      fill_in_reference_for_suggestions if params[:naming].present?

      @observation = Observation.show_includes.find(params[:observation_id])
    end

    # `params[:id]` is guaranteed by the `:edit`/`:update`/`:destroy`
    # routes (`resources :namings`) — let `find` raise on the
    # impossible blank-id case rather than dead-code a consensus
    # fallback for it.
    def naming_from_params
      @observation.namings.find(params[:id])
    end

    def init_edit_ivars
      @given_name  = @naming.text_name
      @names       = nil
      @valid_names = nil
      @reasons     = @naming.init_reasons
    end

    def render_modal_naming_form
      render(Components::ModalTurboForm.new(
               identifier: modal_identifier,
               title: modal_title,
               user: @user,
               model: @naming,
               observation: @observation,
               form_locals: naming_form_locals.except(:model, :observation)
             ), layout: false)
    end

    def naming_form_locals
      {
        model: @naming,
        observation: @observation,
        local: false,
        show_reasons: true,
        context: params[:context],
        vote: @vote,
        given_name: @given_name,
        reasons: @reasons,
        feedback: naming_feedback
      }
    end

    def naming_feedback
      return {} unless defined?(@names)

      {
        names: @names,
        valid_names: @valid_names,
        suggest_corrections: @suggest_corrections,
        parent_deprecated: @parent_deprecated
      }
    end

    def render_phlex_new
      render(Views::Controllers::Observations::Namings::New.new(
               **naming_phlex_props
             ), layout: true)
    end

    def render_phlex_edit
      render(Views::Controllers::Observations::Namings::Edit.new(
               **naming_phlex_props
             ), layout: true)
    end

    # Successful-create response when the form was opened from the
    # lightbox / matrix-box context: swap the obs's title in both
    # places (it now reflects the new naming), close out the
    # naming modal + the AJAX-progress modal, and clear the
    # identify-this-obs strip. Inlined from
    # `_update_matrix_box.erb`.
    def render_update_matrix_box_streams
      obs_id = @observation.id
      render(turbo_stream: [
               turbo_stream.replace(
                 "observation_what_#{obs_id}",
                 Components::LightboxObservationTitle.new(
                   obs: @observation, user: @user, identify: false
                 )
               ),
               turbo_stream.replace(
                 "box_title_#{obs_id}",
                 Components::MatrixBoxTitle.new(
                   id: obs_id,
                   name: @observation.user_format_name(@user).
                         t.break_name.small_author,
                   type: :observation
                 )
               ),
               turbo_stream.close_modal("modal_obs_#{obs_id}_naming"),
               turbo_stream.remove("modal_obs_#{obs_id}_naming"),
               turbo_stream.close_modal("mo_ajax_progress"),
               turbo_stream.remove("mo_ajax_progress"),
               turbo_stream.remove("observation_identify_#{obs_id}")
             ])
    end

    def naming_phlex_props
      {
        observation: @observation,
        user: @user,
        naming: @naming,
        vote: @vote,
        given_name: @given_name,
        reasons: @reasons,
        feedback: naming_feedback
      }
    end

    def modal_identifier
      case action_name
      when "new", "create"
        "obs_#{@observation.id}_naming"
      when "edit", "update"
        "obs_#{@observation.id}_naming_#{@naming.id}"
      end
    end

    def modal_title
      case action_name
      when "new", "create"
        :create_naming_title.t(id: @observation.id)
      when "edit", "update"
        :edit_naming_title.t(id: @observation.id)
      end
    end

    def redirect_to_obs(obs)
      redirect_to(obs.show_link_args)
    end

    ##########################################################################
    #    CREATE

    # returns Boolean. Also called by create_new_naming.
    # Uses resolve_name from ObservationsController::Validators
    def rough_draft
      @naming = Naming.construct({}, @observation)
      @vote = Vote.construct(params.dig(:naming, :vote), @naming)
      success = if params.dig(:naming, :name)
                  resolve_name
                else
                  true
                end
      @naming.name = @name
      success && @name
    end

    # We should have a @name by this point
    def can_save?
      unproposed_name(:runtime_create_naming_already_proposed) &&
        valid_use_of_imageless(@name, @observation) &&
        validate_object(@naming) &&
        (@vote.value.nil? || validate_object(@vote))
    end

    def unproposed_name(warning)
      if @consensus.name_been_proposed?(@name)
        flash_warning(warning.t)
      else
        true
      end
    end

    # Restricts use of "Imageless" as a naming
    # Note that obs.has_backup_data? requires eager loading
    # species_lists and herbarium_records...
    def valid_use_of_imageless(name, obs)
      return true unless name.imageless? && obs.has_backup_data?

      flash_warning(:runtime_bad_use_of_imageless.t)
    end

    def save_changes
      update_naming(params.dig(:naming, :reasons), params[:was_js_on] == "yes")
      save_with_log(@user, @naming)
      change_vote_with_log unless @vote.value.nil?
    end

    def respond_to_successful_create
      respond_to do |format|
        format.turbo_stream do
          case params[:context]
          when "lightgallery", "matrix_box"
            render_update_matrix_box_streams
          else
            redirect_to_obs(@observation)
          end
          return
        end
        format.html { redirect_to_obs(@observation) }
      end
    end

    def flash_naming_errors
      if @given_name.blank?
        flash_error(:form_naming_what_missing.t)
      elsif name_missing?
        flash_object_errors(@naming)
      end
    end

    def name_missing?
      return false if @name && @given_name.present?

      @naming.errors.
        add(:name, :form_observations_there_is_a_problem_with_name.t)
      true
    end

    def respond_to_form_errors
      respond_to do |format|
        format.html do
          case action_name
          when "create" then render_phlex_new
          when "update" then render_phlex_edit
          end and return
        end
        format.turbo_stream do
          render(
            partial: "shared/modal_form_reload",
            locals: {
              identifier: modal_identifier,
              form_locals: naming_form_locals
            }
          ) and return true
        end
      end
    end

    def fill_in_reference_for_suggestions
      @reasons.each_value do |r|
        r.notes = "AI Observer" if r.num == 2
      end
    end

    ##########################################################################
    #    UPDATE

    def can_update?
      validate_naming &&
        (name_not_changing? ||
         unproposed_name(:runtime_edit_naming_someone_else) &&
         valid_use_of_imageless(@name, @observation))
    end

    def validate_naming
      success = resolve_name
      flash_naming_errors
      success
    end

    def name_not_changing?
      @naming.name == @name
    end

    def need_new_naming?
      !(@consensus.editable?(@naming) || name_not_changing?)
    end

    def add_reasons(reasons)
      @reasons = @naming.init_reasons(reasons)
    end

    # Use case: user changes their mind on a name they've proposed, but it's
    # already been upvoted by others. We don't let them change this naming,
    # because that would bring the other people's votes along with it.
    # We make a new one, reusing the user's previously stated vote and reasons.
    def create_new_naming
      rough_draft
      return unless validate_object(@naming) && validate_object(@vote)

      update_naming(params.dig(:naming, :reasons), params[:was_js_on] == "yes")
      # need to save the naming before we can move this user's vote
      save_with_log(@user, @naming)
      change_vote_with_log
      flash_warning(:create_new_naming_warn.l)
    end

    def change_vote_with_log
      @consensus.change_vote_with_log(@naming, @vote.value)
    end

    def change_vote(new_val)
      if new_val && (!@vote || @vote.value != new_val)
        @consensus.change_vote(@naming, new_val)
      else
        @consensus.reload_namings_and_votes!
        @consensus.calc_consensus
      end
    end

    def update_naming(reasons, was_js_on)
      @naming.name = @name
      @naming.create_reasons(reasons, was_js_on)
    end

    def change_naming
      return unless update_name(params.dig(:naming, :reasons),
                                params[:was_js_on] == "yes")

      flash_notice(:runtime_naming_updated_at.t)
      change_vote(params.dig(:naming, :vote, :value).to_i)
    end

    def update_name(reasons, was_js_on)
      @consensus.clean_votes(@naming, @name, @user)
      @naming.create_reasons(reasons, was_js_on)
      @naming.update_object(@name, @naming.changed?)
    end

    def destroy_if_we_can(naming)
      if !permission!(naming)
        flash_error(:runtime_destroy_naming_denied.t(id: naming.id))
      elsif !in_admin_mode? && !@consensus.deletable?(naming)
        flash_warning(:runtime_destroy_naming_someone_else.t)
      elsif !naming.destroy
        flash_error(:runtime_destroy_naming_failed.t(id: naming.id))
      else
        destroy_sibling_namings(naming)
        true
      end
    end

    def destroy_sibling_namings(naming)
      return unless @observation.occurrence_id

      Naming.where(
        name_id: naming.name_id,
        user_id: naming.user_id,
        observation_id: @observation.occurrence.observation_ids
      ).where.not(id: naming.id).destroy_all
    end
  end
end
