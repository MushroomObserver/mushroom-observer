# frozen_string_literal: true

# Controller for handling the naming of observations

module Observations
  class NamingsController < ApplicationController # rubocop:disable Metrics/ClassLength
    before_action :login_required
    before_action :pass_query_params

    # Bullet wants us to eager load interests on taxa, which is loaded in
    # Naming#create_emails
    around_action :skip_bullet, if: -> { defined?(Bullet) },
                                only: [:create, :update]

    # The route for the namings table, an index of this obs' namings
    def index
      @observation = find_or_goto_index(Observation, params[:observation_id])
      @consensus = Observation::NamingConsensus.new(@observation)
    end

    # Note that every Naming form is also a nested Vote form.
    def new
      init_ivars
      return unless @observation

      respond_to do |format|
        format.turbo_stream { render_modal_naming_form }
        format.html
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
      # N+1: What is this doing? Watch out for check_permission!
      return redirect_to_obs(@observation) unless check_permission!(@naming)

      init_edit_ivars
      @consensus = Observation::NamingConsensus.new(@observation)
      @vote = @consensus.owners_vote(@naming)

      respond_to do |format|
        format.turbo_stream { render_modal_naming_form }
        format.html
      end
    end

    def update
      init_ivars
      @observation = Observation.show_includes.find(params[:observation_id])
      @naming = naming_from_params
      # N+1: What is this doing? Watch out for check_permission!
      return redirect_to_obs(@observation) unless check_permission!(@naming)

      @consensus = Observation::NamingConsensus.new(@observation)
      @vote = @consensus.owners_vote(@naming)

      if can_update?
        need_new_naming? ? create_new_naming : change_naming
        redirect_to_obs(@observation)
      else
        add_reasons(params.dig(:naming, :reasons))
        respond_to_form_errors
      end
    end

    def destroy
      naming = Naming.includes([:votes]).find(params[:id].to_s)
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

    # There seems to be a chance the id will be blank, although i believe not.
    def naming_from_params
      if params[:id].blank?
        @consensus = Observation::NamingConsensus.new(@observation)
        @consensus.consensus_naming
      else
        @observation.namings.find(params[:id])
      end
    end

    def init_edit_ivars
      @given_name = @naming.text_name
      @names       = nil
      @valid_names = nil
      @reasons     = @naming.init_reasons
    end

    def render_modal_naming_form
      render(partial: "shared/modal_form",
             locals: {
               title: modal_title, local: false,
               identifier: modal_identifier,
               form: "observations/namings/form",
               form_locals: { show_reasons: true,
                              context: params[:context] }
             }) and return
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
        helpers.naming_form_new_title(obs: @observation)
      when "edit", "update"
        helpers.naming_form_edit_title(obs: @observation)
      end
    end

    def redirect_to_obs(obs)
      redirect_with_query(obs.show_link_args)
    end

    ##########################################################################
    #    CREATE

    # returns Boolean
    def rough_draft
      set_ivars_for_validation(
        {}, # naming_args
        params.dig(:naming, :vote), # vote_args
        params.dig(:naming, :name), # name_str
        params[:approved_name], # approved_name
        params.dig(:chosen_name, :name_id).to_s # chosen_name
      )
    end

    # returns Boolean. Was @params.rough_draft
    def set_ivars_for_validation(naming_args, vote_args,
                                 name_str = nil, approved_name = nil,
                                 chosen_name = nil)
      @naming = Naming.construct(naming_args, @observation)
      @vote = Vote.construct(vote_args, @naming)
      result = if name_str
                 resolve_name(name_str, approved_name, chosen_name)
               else
                 true
               end
      @naming.name = @name
      result
    end

    # Set the ivars for the form, and potentially form_name_feedback
    # in the case the name is not resolved unambiguously
    def resolve_name(given_name, approved_name, chosen_name)
      @resolver = Naming::NameResolver.new(
        given_name, approved_name, chosen_name
      )
      # NOTE: views could be refactored to access properties of the @resolver,
      # e.g. `@resolver.valid_names`, instead of these ivars.
      # All but success, @given_name, @name are only used by form_name_feedback.
      success = false
      @resolver.results.each do |ivar, value|
        if ivar == :success
          # `success' is not allowed as an instance variable name
          success = value
        else
          instance_variable_set(ivar, value)
        end
      end
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
      save_with_log(@naming)
      change_vote_with_log unless @vote.value.nil?
    end

    def respond_to_successful_create
      respond_to do |format|
        format.turbo_stream do
          case params[:context]
          when "lightgallery", "matrix_box"
            render(partial: "observations/namings/update_matrix_box",
                   locals: { obs: @observation })
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
      redo_action = case action_name
                    when "create"
                      :new
                    when "update"
                      :edit
                    end
      respond_to do |format|
        format.html { render(action: redo_action) and return }
        format.turbo_stream do
          render(partial: "shared/modal_form_reload",
                 locals: {
                   identifier: modal_identifier,
                   form: "observations/namings/form",
                   form_locals: { show_reasons: true,
                                  context: params[:context] }
                 }) and return true
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
      validate_name &&
        (name_not_changing? ||
         unproposed_name(:runtime_edit_naming_someone_else) &&
         valid_use_of_imageless(@name, @observation))
    end

    def validate_name
      success = resolve_name(params.dig(:naming, :name).to_s,
                             params[:approved_name],
                             params.dig(:chosen_name, :name_id).to_s)
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

    # Define local_assigns for the update_observation partial
    # @observation.reload doesn't do the includes
    # This is a reload of all the naming table associations, after update
    # The destroy action already preloads the obs, however.
    def locals_for_update_observation(preloaded_obs = nil)
      obs = preloaded_obs || Observation.naming_includes.find(@observation.id)
      consensus = Observation::NamingConsensus.new(obs)
      owner_name = consensus.owner_preference

      [obs, consensus, owner_name]
    end

    # Use case: user changes their mind on a name they've proposed, but it's
    # already been upvoted by others. We don't let them change this naming,
    # because that would bring the other people's votes along with it.
    # We make a new one, reusing the user's previously stated vote and reasons.
    def create_new_naming
      set_ivars_for_validation({}, params.dig(:naming, :vote))
      return unless validate_object(@naming) && validate_object(@vote)

      update_naming(params.dig(:naming, :reasons), params[:was_js_on] == "yes")
      # need to save the naming before we can move this user's vote
      save_with_log(@naming)
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
      if !check_permission!(naming)
        flash_error(:runtime_destroy_naming_denied.t(id: naming.id))
      elsif !in_admin_mode? && !@consensus.deletable?(naming)
        flash_warning(:runtime_destroy_naming_someone_else.t)
      elsif !naming.destroy
        flash_error(:runtime_destroy_naming_failed.t(id: naming.id))
      else
        true
      end
    end
  end
end
