# frozen_string_literal: true

# Controller for handling the naming of observations
module Observations
  class NamingsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    def show
      @observation = find_or_goto_index(Observation, params[:id])
    end

    def new
      @params = NamingParams.new(params[:naming])
      @params.observation =
        load_for_show_observation_or_goto_index(params[:observation_id])
      fill_in_reference_for_suggestions(@params) if params[:naming].present?
      return unless @params.observation

      @observation = @params.observation
      @reasons = @params.reasons

      respond_to do |format|
        format.html
        format.turbo_stream do
          render_modal_naming_form(
            title: helpers.naming_form_new_title(obs: @observation)
          )
        end
      end
    end

    def create
      @params = NamingParams.new(params[:naming])
      @params.observation =
        load_for_show_observation_or_goto_index(params[:observation_id])
      fill_in_reference_for_suggestions(@params) if params[:naming].present?
      return unless @params.observation

      @observation = @params.observation
      @reasons = @params.reasons
      create_post
    end

    def edit
      @params = NamingParams.new
      naming = @params.naming = Naming.from_params(params)
      @params.observation =
        load_for_show_observation_or_goto_index(naming.observation_id)
      unless check_permission!(naming)
        return default_redirect(naming.observation)
      end

      @params.vote = naming.owners_vote
      @params.edit_init

      @observation = @params.observation
      @reasons = @params.reasons

      respond_to do |format|
        format.html
        format.turbo_stream do
          render_modal_naming_form(
            title: helpers.naming_form_edit_title(obs: @observation)
          )
        end
      end
    end

    def update
      @params = NamingParams.new
      naming = @params.naming = Naming.from_params(params)
      @params.observation =
        load_for_show_observation_or_goto_index(naming.observation_id)
      unless check_permission!(naming)
        return default_redirect(naming.observation)
      end

      @params.vote = naming.owners_vote

      @observation = @params.observation
      @reasons = @params.reasons
      edit_post
    end

    def destroy
      naming = Naming.find(params[:id].to_s)
      if destroy_if_we_can(naming)
        flash_notice(:runtime_destroy_naming_success.t(id: params[:id].to_s))
      end
      respond_to do |format|
        format.html { default_redirect(naming.observation) }
        format.turbo_stream do
          @observation = naming.observation
          render(partial: "update_observation") and return
        end
      end
    end

    private

    def render_modal_naming_form(title:)
      render(partial: "shared/modal_form",
             locals: {
               title: title, local: false,
               identifier: "naming_#{@observation.id}",
               form: "observations/namings/form",
               form_locals: { show_reasons: true,
                              context: params[:context] }
             }) and return
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
      respond_to do |format|
        format.turbo_stream do
          case params[:context]
          when "lightbox", "matrix_box"
            render(partial: "observations/namings/update_matrix_box")
          else
            render(partial: "observations/namings/update_observation")
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
                   identifier: "naming_#{@observation.id}",
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

    def edit_post
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
      respond_to do |format|
        format.html { default_redirect(@params.observation) }
        format.turbo_stream do
          render(partial: "observations/namings/update_observation") and return
        end
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
