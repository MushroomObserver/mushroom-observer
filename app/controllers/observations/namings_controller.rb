# frozen_string_literal: true

# Controller for handling the naming of observations
module Observations
  class NamingsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # The route for the namings table, an index of this obs' namings
    def index
      @observation = find_or_goto_index(Observation, params[:id])
    end

    def new
      @params = NamingParams.new(params[:naming])
      fill_in_reference_for_suggestions(@params) if params[:naming].present?
      # N+1: All CRUD actions:
      # The proper `includes` scope here may depend on the response format.
      # The turbo response only needs `naming_includes`, but the html response
      # for the form may need the whole `show_includes` shebang. (Check!)
      # Both need to have the @observation ivar.
      # 
      @observation = @params.observation =
        Observation.show_includes.find(params[:observation_id])
      return unless @params.observation

      @reasons = @params.reasons
      respond_to do |format|
        format.turbo_stream { render_modal_naming_form }
        format.html
      end
    end

    # Note that the `respond_to_successful_` actions do reload the associations
    # after the save/update. Maybe naming_includes are enough here?
    #
    def create
      @params = NamingParams.new(params[:naming])
      fill_in_reference_for_suggestions(@params) if params[:naming].present?
      @observation = @params.observation =
        Observation.show_includes.find(params[:observation_id])
      return unless @params.observation

      @reasons = @params.reasons
      create_post
    end

    def edit
      @params = NamingParams.new
      @observation = @params.observation =
        Observation.show_includes.find(params[:observation_id])
      @naming = @params.naming = naming_from_params
      # N+1: What is this doing? Watch out for check_permission!
      return default_redirect(@observation) unless check_permission!(@naming)

      # N+1: Does this look up votes again? It did
      @params.vote = @naming.owners_vote
      @params.edit_init

      @reasons = @params.reasons

      respond_to do |format|
        format.turbo_stream { render_modal_naming_form }
        format.html
      end
    end

    def update
      @params = NamingParams.new
      @observation = @params.observation =
        Observation.show_includes.find(params[:observation_id])
      @naming = @params.naming = naming_from_params
      # N+1: What is this doing? Watch out for check_permission!
      return default_redirect(@observation) unless check_permission!(@naming)

      # N+1: Does this look up votes again? It did
      @params.vote = @naming.owners_vote

      @reasons = @params.reasons
      update_post
    end

    def destroy
      naming = Naming.find(params[:id].to_s)
      if destroy_if_we_can(naming)
        flash_notice(:runtime_destroy_naming_success.t(id: params[:id].to_s))
      end
      # Now, eager-load the obs without the deleted naming
      @observation = Observation.show_includes.find(params[:observation_id])

      respond_to do |format|
        format.turbo_stream do
          render(partial: "observations/namings/update_observation",
                 locals: { obs: @observation }) and return
        end
        format.html { default_redirect(@observation) }
      end
    end

    private

    # There seems to be a chance the id will be blank, although i believe not.
    def naming_from_params
      if params[:id].blank?
        @observation.consensus_naming
      else
        @observation.namings.find(params[:id])
      end
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

    def default_redirect(obs, action = :show)
      redirect_with_query(controller: "/observations",
                          action: action, id: obs.id)
    end

    def create_post
      if rough_draft && can_save?
        save_changes
        respond_to_successful_create
      else # If anything failed reload the form.
        flash_object_errors(@params.naming) if @params.name_missing?
        @params.add_reasons(param_lookup([:naming, :reasons]))
        respond_to_form_errors
      end
    end

    def respond_to_successful_create
      # @observation.reload doesn't do the includes
      # This is a reload of all the naming table associations, after save
      obs = Observation.naming_includes.find(@observation.id)

      respond_to do |format|
        format.turbo_stream do
          case params[:context]
          when "lightgallery", "matrix_box"
            render(partial: "observations/namings/update_matrix_box",
                   locals: { obs: obs })
          else
            render(partial: "observations/namings/update_observation",
                   locals: { obs: obs })
          end
          return
        end
        format.html { default_redirect(@params.observation, :show) }
      end
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

    def fill_in_reference_for_suggestions(params)
      params.reasons.each_value do |r|
        r.notes = "AI Observer" if r.num == 2
      end
    end

    def rough_draft
      @params.rough_draft(
        {},
        param_lookup([:naming, :vote]),
        param_lookup([:naming, :name]),
        params[:approved_name],
        param_lookup([:chosen_name, :name_id], "").to_s
      )
    end

    def can_save?
      unproposed_name(:runtime_create_naming_already_proposed) &&
        valid_use_of_imageless(@params.name, @params.observation) &&
        validate_object(@params.naming) &&
        (@params.vote.value.nil? || validate_object(@params.vote))
    end

    def save_changes
      @params.update_naming(param_lookup([:naming, :reasons]),
                            params[:was_js_on] == "yes")
      save_with_log(@params.naming)
      @params.save_vote unless @params.vote.value.nil?
    end

    def unproposed_name(warning)
      @params.name_been_proposed? ? flash_warning(warning.t) : true
    end

    def valid_use_of_imageless(name, obs)
      return true unless name.imageless? && obs.has_backup_data?

      flash_warning(:runtime_bad_use_of_imageless.t)
    end

    def validate_name
      success = resolve_name(param_lookup([:naming, :name], "").to_s,
                             param_lookup([:chosen_name, :name_id], "").to_s)
      flash_object_errors(@params.naming) if @params.name_missing?
      success
    end

    def resolve_name(given_name, chosen_name)
      @params.resolve_name(given_name, params[:approved_name], chosen_name)
    end

    def update_post
      if validate_name &&
         (@params.name_not_changing? ||
          unproposed_name(:runtime_edit_naming_someone_else) &&
          valid_use_of_imageless(@params.name, @params.observation))
        @params.need_new_naming? ? create_new_naming : change_naming
        respond_to_successful_update
      else
        @params.add_reasons(param_lookup([:naming, :reasons]))
        respond_to_form_errors
      end
    end

    def respond_to_successful_update
      # @observation.reload doesn't do the includes
      # This is a reload of all the naming table associations, after update
      obs = Observation.naming_includes.find(@observation.id)

      respond_to do |format|
        format.turbo_stream do
          render(partial: "observations/namings/update_observation",
                 locals: { obs: obs }) and return
        end
        format.html { default_redirect(@params.observation) }
      end
    end

    def create_new_naming
      @params.rough_draft({}, param_lookup([:naming, :vote]))
      naming = @params.naming
      return unless validate_object(naming) && validate_object(@params.vote)

      naming.create_reasons(param_lookup([:naming, :reasons]),
                            params[:was_js_on] == "yes")
      save_with_log(naming)
      @params.logged_change_vote
      flash_warning(:create_new_naming_warn.l)
    end

    def change_naming
      return unless @params.update_name(@user,
                                        param_lookup([:naming, :reasons]),
                                        params[:was_js_on] == "yes")

      flash_notice(:runtime_naming_updated_at.t)
      @params.change_vote(param_lookup([:naming, :vote, :value], &:to_i))
    end

    def destroy_if_we_can(naming)
      if !check_permission!(naming)
        flash_error(:runtime_destroy_naming_denied.t(id: naming.id))
      elsif !in_admin_mode? && !naming.deletable?
        flash_warning(:runtime_destroy_naming_someone_else.t)
      elsif !naming.destroy
        flash_error(:runtime_destroy_naming_failed.t(id: naming.id))
      else
        true
      end
    end
  end
end
