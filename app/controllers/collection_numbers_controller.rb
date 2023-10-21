# frozen_string_literal: true

# Controls viewing and modifying collection numbers.
class CollectionNumbersController < ApplicationController
  before_action :login_required
  before_action :pass_query_params, only: [
    :show, :new, :create, :edit, :update, :destroy
  ]
  before_action :store_location, only: [
    :show, :new, :create, :edit, :update
  ]

  # Used by ApplicationController to dispatch #index to a private method
  @index_subaction_param_keys = [
    :pattern,
    :observation_id,
    :by,
    :q,
    :id
  ].freeze

  @index_subaction_dispatch_table = {
    by: :index_query_results,
    q: :index_query_results,
    id: :index_query_results
  }.freeze

  def show
    case params[:flow]
    when "next"
      redirect_to_next_object(:next, CollectionNumber, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, CollectionNumber, params[:id]) and return
    end

    @canonical_url = CollectionNumber.show_url(params[:id])
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
  end

  def new
    set_ivars_for_new
    return unless @observation

    @back_object = @observation
    return unless make_sure_can_edit!(@observation)

    @collection_number = CollectionNumber.new(name: @user.legal_name)

    respond_to do |format|
      format.html
      format.js do
        render_modal_collection_number_form(
          title: helpers.collection_number_form_new_title
        )
      end
    end
  end

  def create
    set_ivars_for_new
    return unless @observation

    @back_object = @observation
    return unless make_sure_can_edit!(@observation)

    create_collection_number # response handled here
  end

  def edit
    set_ivars_for_edit
    return unless @collection_number

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!(@collection_number)

    respond_to do |format|
      format.html
      format.js do
        render_modal_collection_number_form(
          title: helpers.collection_number_form_edit_title(
            c_n: @collection_number
          )
        )
      end
    end
  end

  def update
    set_ivars_for_edit
    return unless @collection_number

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!(@collection_number)

    update_collection_number # response handled here
  end

  def destroy
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
    return unless @collection_number
    return unless make_sure_can_delete!(@collection_number)

    @collection_number.destroy
    respond_to do |format|
      format.html do
        redirect_with_query(action: :index)
      end
      format.js do
        render_collection_numbers_section_update
      end
    end
  end

  ##############################################################################

  private

  def render_modal_collection_number_form(title:)
    render(partial: "shared/modal_form_show",
           locals: { title: title, identifier: "collection_number" }) and return
  end

  def render_collection_numbers_section_update
    render(
      partial: "observations/show/section_update",
      locals: { identifier: "collection_numbers" }
    ) and return
  end

  def default_index_subaction
    list_all
  end

  # Show list of collection_numbers.
  def list_all
    store_location
    query = create_query(:CollectionNumber, :all)
    show_selected_collection_numbers(query)
  end

  # Displays matrix of selected CollectionNumber's (based on current Query).
  def index_query_results
    query = find_or_create_query(:CollectionNumber, by: params[:by])
    show_selected_collection_numbers(query, id: params[:id].to_s,
                                            always_index: true)
  end

  # Display list of CollectionNumbers whose text matches a string pattern.
  def pattern
    pat = params[:pattern].to_s
    if pat.match?(/^\d+$/) &&
       (collection_number = CollectionNumber.safe_find(pat))
      redirect_to(action: :show, id: collection_number.id)
    else
      query = create_query(:CollectionNumber, :pattern_search, pattern: pat)
      show_selected_collection_numbers(query)
    end
  end

  # Display list of CollectionNumbers for an Observation
  def observation_id
    @observation = Observation.find(params[:observation_id])
    store_location
    query = create_query(:CollectionNumber, :for_observation,
                         observation: params[:observation_id].to_s)
    show_selected_collection_numbers(query, always_index: true)
  end

  def show_selected_collection_numbers(query, args = {})
    args = {
      action: :index,
      letters: "collection_numbers.name",
      num_per_page: 100
    }.merge(args)

    show_index_of_objects(query, args)
  end

  def set_ivars_for_new
    @layout = calc_layout_params
    @observation = find_or_goto_index(Observation, params[:observation_id])
  end

  def set_ivars_for_edit
    @layout = calc_layout_params
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
  end

  # create
  def create_collection_number
    @collection_number =
      CollectionNumber.new(permitted_collection_number_params)
    normalize_parameters
    return if flash_error_and_reload_if_form_has_errors

    if name_and_number_free?
      save_collection_number_and_update_associations
    else
      flash_collection_number_already_used_and_return
    end
  end

  # create, update
  def flash_error_and_reload_if_form_has_errors
    redirect_params = case action_name # this is a rails var
                      when "create"
                        { action: :new }
                      when "update"
                        { action: :edit }
                      end
    redirect_params = redirect_params.merge({ back: @back }) if @back.present?

    if @collection_number.name.blank? || @collection_number.number.blank?
      if @collection_number.name.blank?
        flash_error(:create_collection_number_missing_name.t)
      elsif @collection_number.number.blank?
        flash_error(:create_collection_number_missing_number.t)
      end
      respond_to do |format|
        format.html do
          redirect_to(redirect_params) and return true
        end
        format.js do
          render(partial: "shared/modal_form_reload",
                 locals: { identifier: "collection_number",
                           form: "collection_numbers/form" }) and return true
        end
      end
    end
    false
  end

  # create
  def save_collection_number_and_update_associations
    @collection_number.save
    @collection_number.add_observation(@observation)
    flash_notice(
      :runtime_added_to.t(type: :collection_number, name: :observation)
    )
    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @collection_number)
      end
      format.js do
        render_collection_numbers_section_update
      end
    end
  end

  # create
  def flash_collection_number_already_used_and_return
    flash_warning(:edit_collection_number_already_used.t) if
      @other_number.observations.any?
    @other_number.add_observation(@observation)
    @collection_number = @other_number
    show_flash_and_send_back
  end

  # update
  def update_collection_number
    old_format_name = @collection_number.format_name
    @collection_number.attributes = permitted_collection_number_params
    normalize_parameters
    return if flash_error_and_reload_if_form_has_errors

    if name_and_number_free?
      update_collection_number_and_associations(old_format_name)
    else
      flash_numbers_merged_and_update_associations(old_format_name)
    end
  end

  # update
  def update_collection_number_and_associations(old_format_name)
    @collection_number.save
    @collection_number.change_corresponding_herbarium_records(old_format_name)
    flash_notice(:runtime_updated_at.t(type: :collection_number))

    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @collection_number)
      end
      @observation = @back_object # if we're here, we're on an obs page
      format.js do
        render_collection_numbers_section_update
      end
    end
  end

  # update
  def flash_numbers_merged_and_update_associations(old_format_name)
    flash_warning(
      :edit_collection_numbers_merged.t(
        this: old_format_name,
        that: @other_number.format_name
      )
    )
    @collection_number.change_corresponding_herbarium_records(old_format_name)
    @other_number.observations += @collection_number.observations -
                                  @other_number.observations
    @collection_number.destroy
    @collection_number = @other_number

    show_flash_and_send_back
  end

  def permitted_collection_number_params
    return {} unless params[:collection_number]

    params.require(:collection_number).permit(:name, :number)
  end

  def make_sure_can_edit!(obj)
    return true if in_admin_mode? || obj.can_edit?

    flash_error(:permission_denied.t)
    show_flash_and_send_back
    false
  end

  def make_sure_can_delete!(collection_number)
    return true if collection_number.can_edit? || in_admin_mode?

    flash_error(:permission_denied.t)
    redirect_to(collection_number_path(collection_number.id))
    false
  end

  def normalize_parameters
    [:name, :number].each do |arg|
      val = @collection_number.send(arg).to_s.strip_html.strip_squeeze
      @collection_number.send("#{arg}=", val)
    end
  end

  def name_and_number_free?
    @other_number = CollectionNumber.where(
      name: @collection_number.name,
      number: @collection_number.number
    ).first
    !@other_number || @other_number == @collection_number
  end

  def figure_out_where_to_go_back_to
    @back = params[:back]
    @back_object = nil
    if @back == "show"
      @back_object = @collection_number
    elsif @back != "index"
      @back_object = Observation.safe_find(@back)
      return if @back_object

      @back_object = if @collection_number.observations.one?
                       @collection_number.observations.first
                     else
                       @collection_number
                     end
    end
  end

  def show_flash_and_send_back
    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @collection_number) and
          return
      end
      format.js do
        # renders the flash in the modal via js
        render(partial: "shared/modal_flash_update") and return
      end
    end
  end
end
