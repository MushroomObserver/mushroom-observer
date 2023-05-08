# frozen_string_literal: true

# Controls viewing and modifying herbarium records.
# rubocop:disable Metrics/ClassLength
class HerbariumRecordsController < ApplicationController
  before_action :login_required
  # disable cop because index is defined in ApplicationController
  # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :pass_query_params, except: :index
  before_action :store_location, except: [:index, :destroy]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  # index
  # ApplicationController uses this table to dispatch #index to a private method
  @index_subaction_param_keys = [
    :pattern,
    :herbarium_id,
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
      redirect_to_next_object(:next, HerbariumRecord, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, HerbariumRecord, params[:id]) and return
    end

    @layout = calc_layout_params
    @canonical_url = HerbariumRecord.show_url(params[:id])
    @herbarium_record = find_or_goto_index(HerbariumRecord, params[:id])
  end

  def new
    set_ivars_for_new
    return unless @observation

    @back_object = @observation
    @herbarium_record = default_herbarium_record

    respond_to do |format|
      format.html
      format.js do
        render(layout: false)
      end
    end
  end

  def create
    set_ivars_for_new
    return unless @observation

    @back_object = @observation
    create_herbarium_record # response handled here
  end

  def edit
    set_ivars_for_edit
    return unless @herbarium_record

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!

    @herbarium_record.herbarium_name = @herbarium_record.herbarium.try(&:name)

    respond_to do |format|
      format.html
      format.js do
        render(layout: false)
      end
    end
  end

  def update
    set_ivars_for_edit
    return unless @herbarium_record

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!

    update_herbarium_record # response handled here
  end

  def destroy
    @herbarium_record = find_or_goto_index(HerbariumRecord, params[:id])
    return unless @herbarium_record
    return unless make_sure_can_delete!(@herbarium_record)

    figure_out_where_to_go_back_to
    @herbarium_record.destroy

    respond_to do |format|
      format.js
      format.html do
        redirect_with_query(action: :index)
      end
    end
  end

  ##############################################################################

  private

  def set_ivars_for_new
    @layout = calc_layout_params
    @observation = find_or_goto_index(Observation, params[:observation_id])
  end

  def set_ivars_for_edit
    @layout = calc_layout_params
    @herbarium_record = find_or_goto_index(HerbariumRecord, params[:id])
  end

  def default_index_subaction
    list_all
  end

  # Show list of herbarium_records.
  def list_all
    store_location
    query = create_query(:HerbariumRecord, :all, by: default_sort_order)
    show_selected_herbarium_records(query)
  end

  def default_sort_order
    ::Query::HerbariumBase.default_order
  end

  # Displays matrix of selected HerbariumRecord's (based on current Query).
  def index_query_results
    query = find_or_create_query(:HerbariumRecord, by: params[:by])
    show_selected_herbarium_records(query, id: params[:id].to_s,
                                           always_index: true)
  end

  # Display list of HerbariumRecords whose text matches a string pattern.
  def pattern
    pattern = params[:pattern].to_s
    if pattern.match?(/^\d+$/) &&
       (herbarium_record = HerbariumRecord.safe_find(pattern))
      redirect_to(herbarium_record_path(herbarium_record.id))
    else
      query = create_query(:HerbariumRecord, :pattern_search, pattern: pattern)
      show_selected_herbarium_records(query)
    end
  end

  def herbarium_id
    store_location
    query = create_query(:HerbariumRecord, :in_herbarium,
                         herbarium: params[:herbarium_id].to_s,
                         by: :herbarium_label)
    show_selected_herbarium_records(query, always_index: true)
  end

  def observation_id
    store_location
    query = create_query(:HerbariumRecord, :for_observation,
                         observation: params[:observation_id].to_s,
                         by: :herbarium_label)
    @links = [
      [:show_object.l(type: :observation),
       observation_path(params[:observation_id])],
      [:create_herbarium_record.l,
       new_herbarium_record_path(id: params[:id])]
    ]
    show_selected_herbarium_records(query, always_index: true)
  end

  def show_selected_herbarium_records(query, args = {})
    args = {
      action: :index,
      letters: "herbarium_records.initial_det",
      num_per_page: 100,
      include: [{ herbarium: :curators }, { observations: :name }, :user]
    }.merge(args)

    @links ||= []
    @links << [:create_herbarium.l, new_herbarium_path]

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["herbarium_name",  :sort_by_herbarium_name.t],
      ["herbarium_label", :sort_by_herbarium_label.t],
      ["created_at",      :sort_by_created_at.t],
      ["updated_at",      :sort_by_updated_at.t]
    ]

    show_index_of_objects(query, args)
  end

  def default_herbarium_record
    HerbariumRecord.new(
      herbarium_name: @user.preferred_herbarium_name,
      initial_det: @observation.name.text_name,
      accession_number: default_accession_number
    )
  end

  def default_accession_number
    if @observation.collection_numbers.length == 1
      @observation.collection_numbers.first.format_name
    else
      "MO #{@observation.id}"
    end
  end

  def create_herbarium_record
    @herbarium_record =
      HerbariumRecord.new(permitted_herbarium_record_params)
    normalize_parameters
    return if flash_error_and_reload_if_form_has_errors

    if herbarium_label_free?
      save_herbarium_record_and_update_associations
    else
      if @other_record.can_edit?
        flash_herbarium_record_already_used_and_add_observation
      else
        flash_herbarium_record_already_used_by_someone_else
      end
      show_flash_and_send_back
    end
  end

  def save_herbarium_record_and_update_associations
    @herbarium_record.save
    @herbarium_record.add_observation(@observation)
    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @herbarium_record)
      end
      format.js # updates the observation. @back_object is set already
    end
  end

  def flash_herbarium_record_already_used_and_add_observation
    flash_warning(:create_herbarium_record_already_used.t) if
      @other_record.observations.any?
    @other_record.add_observation(@observation)
  end

  def flash_herbarium_record_already_used_by_someone_else
    flash_error(:create_herbarium_record_already_used_by_someone_else.
      t(herbarium_name: @herbarium_record.herbarium.name))
  end

  def update_herbarium_record
    old_herbarium = @herbarium_record.herbarium
    @herbarium_record.attributes = permitted_herbarium_record_params
    normalize_parameters
    return if flash_error_and_reload_if_form_has_errors

    if herbarium_label_free?
      update_herbarium_record_and_notify_curators(old_herbarium)
    else
      flash_warning(:edit_herbarium_record_already_used.t)
      show_flash_and_send_back
    end
  end

  def update_herbarium_record_and_notify_curators(old_herbarium)
    @herbarium_record.save
    @herbarium_record.notify_curators if
      @herbarium_record.herbarium != old_herbarium

    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @herbarium_record)
      end
      @observation = @back_object # if we're here, we're on an obs page
      format.js # updates the page
    end
  end

  def flash_error_and_reload_if_form_has_errors
    redirect_params = case action_name # this is a rails var
                      when "create"
                        { action: :new }
                      when "update"
                        { action: :edit }
                      end
    redirect_params = redirect_params.merge({ back: @back }) if @back.present?

    unless validate_herbarium_name! # may add flashes
      respond_to do |format|
        format.html do
          redirect_to(redirect_params) and return true
        end
        format.js do
          render(partial: "form_reload",
                 locals: { action: action_name.to_sym }) and return true
        end
      end
    end

    show_flash_and_send_back and return true unless can_add_record_to_herbarium?

    false
  end

  def permitted_herbarium_record_params
    return {} unless params[:herbarium_record]

    params.require(:herbarium_record).
      permit(:herbarium_name, :initial_det, :accession_number, :notes)
  end

  def make_sure_can_edit!
    return true if in_admin_mode? || @herbarium_record.can_edit?
    return true if @herbarium_record.herbarium.curator?(@user)

    flash_error(:permission_denied.t)
    redirect_to_back_object_or_object(@back_object, @herbarium_record)
    false
  end

  def make_sure_can_delete!(herbarium_record)
    return true if herbarium_record.can_edit? || in_admin_mode?
    return true if herbarium_record.herbarium.curator?(@user)

    flash_error(:permission_denied.t)
    redirect_to(herbarium_record_path(herbarium_record))
    false
  end

  def normalize_parameters
    [:herbarium_name, :initial_det, :accession_number].each do |arg|
      val = @herbarium_record.send(arg).to_s.strip_html.strip_squeeze
      @herbarium_record.send("#{arg}=", val)
    end
    @herbarium_record.notes = @herbarium_record.notes.to_s.strip
  end

  def validate_herbarium_name!
    name = @herbarium_record.herbarium_name.to_s
    name2 = name.sub(/^[^-]* - /, "")
    herbarium = Herbarium.where(name: [name, name2]).first ||
                Herbarium.where(code: name).first
    @herbarium_record.herbarium = herbarium
    if name.blank?
      flash_error(:create_herbarium_record_missing_herbarium_name.t)
      false
    elsif !@herbarium_record.herbarium.nil?
      true
    elsif name != @user.personal_herbarium_name || @user.personal_herbarium
      flash_warning(:create_herbarium_separately.t)
      false
    else
      @herbarium_record.herbarium = @user.create_personal_herbarium
      true
    end
  end

  def can_add_record_to_herbarium?
    return true if in_admin_mode?
    return true if @observation&.can_edit?
    return true if @herbarium_record.observations.any?(&:can_edit?)
    return true if @herbarium_record.herbarium.curator?(@user)

    flash_error(:create_herbarium_record_only_curator_or_owner.t)
    false
  end

  def herbarium_label_free?
    @other_record = HerbariumRecord.where(
      herbarium: @herbarium_record.herbarium,
      accession_number: @herbarium_record.accession_number
    ).first
    !@other_record || @other_record == @herbarium_record
  end

  def figure_out_where_to_go_back_to
    @back = params[:back].to_s
    @back_object = nil
    if @back == "show"
      @back_object = @herbarium_record
    elsif @back != "index"
      @back_object = Observation.safe_find(@back)
      return if @back_object

      @back_object = if @herbarium_record.observations.count == 1
                       @herbarium_record.observations.first
                     else
                       @herbarium_record
                     end
    end
  end

  def show_flash_and_send_back
    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @herbarium_record) and
          return
      end
      format.js do
        # renders the flash in the modal via js
        render(partial: "shared/update_modal_flash") and return
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
