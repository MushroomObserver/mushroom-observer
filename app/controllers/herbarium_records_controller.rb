# frozen_string_literal: true

# Controls viewing and modifying herbarium records.
class HerbariumRecordsController < ApplicationController
  before_action :login_required, except: [
    :index_herbarium_record,
    :index,
    :list_herbarium_records, # aliased
    :herbarium_record_search,
    :herbarium_index,
    :observation_index,
    :show,
    :show_herbarium_record, # aliased
    :show_next,
    :show_prev,
    :next_herbarium_record, # aliased
    :prev_herbarium_record # aliased
  ]

  # Displays matrix of selected HerbariumRecord's (based on current Query).
  def index_herbarium_record
    query = find_or_create_query(:HerbariumRecord, by: params[:by])
    show_selected_herbarium_records(query, id: params[:id].to_s,
                                           always_index: true)
  end

  # Show list of herbarium_records.
  def index
    store_location
    query = create_query(:HerbariumRecord, :all, by: :herbarium_label)
    show_selected_herbarium_records(query)
  end

  alias_method :list_herbarium_records, :index

  # Display list of HerbariumRecords whose text matches a string pattern.
  def herbarium_record_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (@herbarium_record = HerbariumRecord.safe_find(pattern))
      # redirect_to(
      #   action: :show_herbarium_record,
      #   id: @herbarium_record.id
      # )
      redirect_to herbarium_record_path(@herbarium_record.id)
    else
      query = create_query(:HerbariumRecord, :pattern_search, pattern: pattern)
      show_selected_herbarium_records(query)
    end
  end

  def herbarium_index
    store_location
    query = create_query(:HerbariumRecord, :in_herbarium,
                         herbarium: params[:id].to_s, by: :herbarium_label)
    show_selected_herbarium_records(query, always_index: true)
  end

  def observation_index
    store_location
    query = create_query(:HerbariumRecord, :for_observation,
                         observation: params[:id].to_s, by: :herbarium_label)
    @links = [
      # [:show_object.l(type: :observation),
      #  Observation.show_link_args(params[:id])],
      [:show_object.l(type: :observation),
       observation_path(id: params[:id])],
      # [:create_herbarium_record.l,
      #  { action: :new,
      #    id: params[:id] }
      # ]
      [:create_herbarium_record.l,
        new_herbarium_record_path(id: params[:id])]
    ]
    show_selected_herbarium_records(query, always_index: true)
  end

  def show
    store_location
    pass_query_params
    @layout = calc_layout_params
    @canonical_url = HerbariumRecord.show_url(params[:id])
    @herbarium_record = find_or_goto_index(HerbariumRecord, params[:id])
  end

  alias_method :show_herbarium_record, :show

  def show_next
    redirect_to_next_object(:next, HerbariumRecord, params[:id].to_s)
  end

  alias_method :next_herbarium_record, :show_next

  def show_prev
    redirect_to_next_object(:prev, HerbariumRecord, params[:id].to_s)
  end

  alias_method :prev_herbarium_record, :show_prev

  def new
    store_location
    pass_query_params
    @layout      = calc_layout_params
    @observation = find_or_goto_index(Observation, params[:id])
    return unless @observation

    @back_object = @observation
    if request.method == "GET"
      @herbarium_record = default_herbarium_record
    # elsif request.method == "POST"
    #   post_create_herbarium_record
    else
      redirect_back_or_default("/")
    end
  end

  alias_method :create_herbarium_record, :new

  def create
    @herbarium_record =
      HerbariumRecord.new(whitelisted_herbarium_record_params)
    normalize_parameters
    if !validate_herbarium_name! ||
       !can_add_record_to_herbarium?
      return
    elsif herbarium_label_free?
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

    redirect_to_observation_or_herbarium_record
  end

  alias_method :post_create_herbarium_record, :create

  def edit
    store_location
    pass_query_params
    @layout = calc_layout_params
    @herbarium_record = find_or_goto_index(HerbariumRecord, params[:id])
    return unless @herbarium_record

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!

    @herbarium_record.herbarium_name = @herbarium_record.herbarium.try(&:name)
  end

  alias_method :edit_herbarium_record, :edit

  def update
    old_herbarium = @herbarium_record.herbarium
    @herbarium_record.attributes = whitelisted_herbarium_record_params
    normalize_parameters
    if !validate_herbarium_name! ||
       !can_add_record_to_herbarium?
      return
    elsif herbarium_label_free?
      @herbarium_record.save
      @herbarium_record.notify_curators if
        @herbarium_record.herbarium != old_herbarium
    else
      flash_warning(:edit_herbarium_record_already_used.t)
      return
    end

    redirect_to_observation_or_herbarium_record
  end

  alias_method :post_edit_herbarium_record, :update

  def remove_observation
    pass_query_params
    @herbarium_record = find_or_goto_index(HerbariumRecord, params[:id])
    return unless @herbarium_record

    @observation = find_or_goto_index(Observation, params[:obs])
    return unless @observation
    return unless make_sure_can_delete!(@herbarium_record)

    @herbarium_record.remove_observation(@observation)
    # redirect_with_query(@observation.show_link_args)
    redirect_to observation_path(@observation.id, q: get_query_param)
  end

  def destroy
    pass_query_params
    @herbarium_record = find_or_goto_index(HerbariumRecord, params[:id])
    return unless @herbarium_record
    return unless make_sure_can_delete!(@herbarium_record)

    figure_out_where_to_go_back_to
    @herbarium_record.destroy
    # redirect_with_query(
    #   action: :index_herbarium_record
    # )
    redirect_to herbarium_record_index_herbarium_record_path(
      q: get_query_param
    )
  end

  alias_method :destroy_herbarium_record, :destroy

  ##############################################################################

  private

  def show_selected_herbarium_records(query, args = {})
    args = {
      action: :index,
      letters: "herbarium_records.initial_det",
      num_per_page: 100
    }.merge(args)

    @links ||= []
    # @links << [:create_herbarium.l,
    #            { controller: :herbaria,
    #              action: :new }
    #           ]
    @links << [ link_to :create_herbarium.l, new_herbarium_path ]

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

  def whitelisted_herbarium_record_params
    return {} unless params[:herbarium_record]

    params.require(:herbarium_record).
      permit(:herbarium_name, :initial_det, :accession_number, :notes)
  end

  def make_sure_can_edit!
    return true if in_admin_mode? || @herbarium_record.can_edit?
    return true if @herbarium_record.herbarium.curator?(@user)

    flash_error :permission_denied.t
    redirect_to_observation_or_herbarium_record
    false
  end

  def make_sure_can_delete!(herbarium_record)
    return true if in_admin_mode? || herbarium_record.can_edit?
    return true if herbarium_record.herbarium.curator?(@user)

    flash_error(:permission_denied.t)
    # redirect_to(herbarium_record.show_link_args)
    redirect_to herbarium_record_path(herbarium_record.id)
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
    redirect_to_observation_or_herbarium_record
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

  def redirect_to_observation_or_herbarium_record
    if @back_object
      # redirect_with_query(@back_object.show_link_args)
      redirect_to object_path(@back_object, q: get_query_param)
    else
      # redirect_with_query(
      #   action: :index_herbarium_record,
      #   id: @herbarium_record.id
      # )
      redirect_to herbarium_record_index_herbarium_record_path(
        q: get_query_param
      )
    end
  end
end
