# frozen_string_literal: true

# Controls viewing and modifying herbarium records.
# rubocop:disable Metrics/ClassLength
class HerbariumRecordsController < ApplicationController
  before_action :login_required
  # except: [
  #   :index_herbarium_record,
  #   :list_herbarium_records,
  #   :herbarium_record_search,
  #   :herbarium_index,
  #   :observation_index,
  #   :show_herbarium_record,
  #   :next_herbarium_record,
  #   :prev_herbarium_record
  # ]
  before_action :pass_query_params, except: :index
  before_action :store_location, except: [:index, :destroy]

  # rubocop:disable Metrics/AbcSize
  def index
    if params[:pattern].present? # rubocop:disable Style/GuardClause
      herbarium_record_search and return
    elsif params[:herbarium_id].present?
      herbarium_index and return
    elsif params[:observation_id].present?
      observation_index and return
    elsif params[:by].present? || params[:q].present? || params[:id].present?
      index_herbarium_record and return
    else
      list_herbarium_records and return
    end
  end
  # rubocop:enable Metrics/AbcSize

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
  end

  def create
    set_ivars_for_new
    return unless @observation

    @back_object = @observation
    create_herbarium_record
  end

  def edit
    set_ivars_for_edit
    return unless @herbarium_record

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!

    @herbarium_record.herbarium_name = @herbarium_record.herbarium.try(&:name)
  end

  def update
    set_ivars_for_edit
    return unless @herbarium_record

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!

    update_herbarium_record
  end

  def destroy
    @herbarium_record = find_or_goto_index(HerbariumRecord, params[:id])
    return unless @herbarium_record
    return unless make_sure_can_delete!(@herbarium_record)

    figure_out_where_to_go_back_to
    @herbarium_record.destroy
    redirect_with_query(herbarium_records_path)
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

  # Displays matrix of selected HerbariumRecord's (based on current Query).
  def index_herbarium_record
    query = find_or_create_query(:HerbariumRecord, by: params[:by])
    show_selected_herbarium_records(query, id: params[:id].to_s,
                                           always_index: true)
  end

  # Show list of herbarium_records.
  def list_herbarium_records
    store_location
    query = create_query(:HerbariumRecord, :all, by: :herbarium_label)
    show_selected_herbarium_records(query)
  end

  # Display list of HerbariumRecords whose text matches a string pattern.
  def herbarium_record_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (herbarium_record = HerbariumRecord.safe_find(pattern))
      redirect_to(herbarium_record_path(herbarium_record.id))
    else
      query = create_query(:HerbariumRecord, :pattern_search, pattern: pattern)
      show_selected_herbarium_records(query)
    end
  end

  def herbarium_index
    store_location
    query = create_query(:HerbariumRecord, :in_herbarium,
                         herbarium: params[:herbarium_id].to_s,
                         by: :herbarium_label)
    show_selected_herbarium_records(query, always_index: true)
  end

  def observation_index
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
      HerbariumRecord.new(whitelisted_herbarium_record_params)
    normalize_parameters
    return if check_for_form_errors?

    if herbarium_label_free?
      @herbarium_record.save
      @herbarium_record.add_observation(@observation)
    elsif @other_record.can_edit?
      flash_warning(:create_herbarium_record_already_used.t) if
        @other_record.observations.any?
      @other_record.add_observation(@observation)
    else
      flash_error(:create_herbarium_record_already_used_by_someone_else.
        t(herbarium_name: @herbarium_record.herbarium.name))
      return
    end

    redirect_to_observation_or_object(@herbarium_record)
  end

  def update_herbarium_record
    old_herbarium = @herbarium_record.herbarium
    @herbarium_record.attributes = whitelisted_herbarium_record_params
    normalize_parameters
    return if check_for_form_errors?

    if herbarium_label_free?
      @herbarium_record.save
      @herbarium_record.notify_curators if
        @herbarium_record.herbarium != old_herbarium
    else
      flash_warning(:edit_herbarium_record_already_used.t)
      return
    end

    redirect_to_observation_or_object(@herbarium_record)
  end

  def check_for_form_errors?
    redirect_params = case action_name # this is a rails var
                      when "create"
                        { action: :new }
                      when "update"
                        { action: :edit }
                      end
    redirect_params = redirect_params.merge({ back: @back }) if @back.present?

    redirect_to(redirect_params) and return true unless validate_herbarium_name!

    unless can_add_record_to_herbarium?
      redirect_to_observation_or_object(@herbarium_record) and return true
    end

    false
  end

  def whitelisted_herbarium_record_params
    return {} unless params[:herbarium_record]

    params.require(:herbarium_record).
      permit(:herbarium_name, :initial_det, :accession_number, :notes)
  end

  def make_sure_can_edit!
    return true if in_admin_mode? || @herbarium_record.can_edit?
    return true if @herbarium_record.herbarium.curator?(@user)

    flash_error(:permission_denied.t)
    redirect_to_observation_or_object(@herbarium_record)
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

  def validate_herbarium_name! # rubocop:disable Metrics/AbcSize
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
end
# rubocop:enable Metrics/ClassLength
