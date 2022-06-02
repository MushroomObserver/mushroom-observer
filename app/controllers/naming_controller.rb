# frozen_string_literal: true

# Controller for handling the naming of observations
class NamingController < ApplicationController
  before_action :login_required
  before_action :disable_link_prefetching, except: [:create, :edit]

  def edit
    pass_query_params
    @params = NamingParams.new
    naming = @params.naming = Naming.from_params(params)
    @params.observation =
      load_for_show_observation_or_goto_index(naming.observation_id)
    return default_redirect(naming.observation) unless check_permission!(naming)

    # TODO: Can this get moved into NamingParams#naming=
    @params.vote = naming.owners_vote
    request.method == "POST" ? edit_post : @params.edit_init
  end

  def create
    pass_query_params
    @params = NamingParams.new(params[:name])
    @params.observation =
      load_for_show_observation_or_goto_index(params[:id])
    fill_in_reference_for_suggestions(@params) if params[:name].present?
    return unless @params.observation

    create_post if request.method == "POST"
  end

  def destroy
    pass_query_params
    naming = Naming.find(params[:id].to_s)
    if destroy_if_we_can(naming)
      flash_notice(:runtime_destroy_naming_success.t(id: params[:id].to_s))
    end
    default_redirect(naming.observation)
  end

  private

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

  def create_post
    if rough_draft && can_save?
      save_changes
      default_redirect(@params.observation, :show_observation)
    else # If anything failed reload the form.
      flash_object_errors(@params.naming) if @params.name_missing?
      @params.add_reason(params[:reason])
    end
  end

  def rough_draft
    @params.rough_draft(params[:naming], params[:vote],
                        param_lookup([:name, :name]),
                        params[:approved_name],
                        param_lookup([:chosen_name, :name_id], "").to_s)
  end

  def can_save?
    unproposed_name(:runtime_create_naming_already_proposed) &&
      valid_use_of_imageless(@params.name, @params.observation) &&
      validate_object(@params.naming) &&
      (@params.vote.value.nil? || validate_object(@params.vote))
  end

  def unproposed_name(warning)
    @params.name_been_proposed? ? flash_warning(warning.t) : true
  end

  def valid_use_of_imageless(name, obs)
    return true unless name.imageless? && obs.has_backup_data?

    flash_warning(:runtime_bad_use_of_imageless.t)
  end

  def validate_name
    success = resolve_name(param_lookup([:name, :name], "").to_s,
                           param_lookup([:chosen_name, :name_id], "").to_s)
    flash_object_errors(@params.naming) if @params.name_missing?
    success
  end

  def default_redirect(obs, action = :show_observation)
    redirect_with_query(controller: :observer,
                        action: action,
                        id: obs.id)
  end

  def edit_post
    if validate_name &&
       (@params.name_not_changing? ||
        unproposed_name(:runtime_edit_naming_someone_else) &&
        valid_use_of_imageless(@params.name, @params.observation))
      @params.need_new_naming? ? create_new_naming : change_naming
      default_redirect(@params.observation)
    else
      @params.add_reason(params[:reason])
    end
  end

  def create_new_naming
    @params.rough_draft(params[:naming], params[:vote])
    naming = @params.naming
    return unless validate_object(naming) && validate_object(@params.vote)

    naming.create_reasons(params[:reason], params[:was_js_on] == "yes")
    save_with_log(naming)
    @params.logged_change_vote
    flash_warning(:create_new_naming_warn.l)
  end

  def change_naming
    return unless @params.update_name(@user, params[:reason],
                                      params[:was_js_on] == "yes")

    flash_notice(:runtime_naming_updated_at.t)
    @params.change_vote(param_lookup([:vote, :value], &:to_i))
  end

  def save_changes
    @params.update_naming(params[:reason], params[:was_js_on] == "yes")
    save_with_log(@params.naming)
    @params.save_vote unless @params.vote.value.nil?
  end

  def resolve_name(given_name, chosen_name)
    @params.resolve_name(given_name, params[:approved_name], chosen_name)
  end

  def fill_in_reference_for_suggestions(params)
    params.reason.each_value do |r|
      r.notes = "AI Observer" if r.num == 2
    end
  end
end
