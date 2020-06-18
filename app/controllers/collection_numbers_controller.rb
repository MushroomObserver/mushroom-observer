# frozen_string_literal: true

# Controls viewing and modifying collection numbers.
class CollectionNumbersController < ApplicationController
  before_action :login_required, except: [
    :index_collection_number,
    :index,
    :list_collection_numbers, # aliased
    :collection_number_search,
    :observation_index,
    :show,
    :show_next,
    :show_prev,
    :show_collection_number, # aliased
    :next_collection_number, # aliased
    :prev_collection_number # aliased
  ]

  # Displays matrix of selected CollectionNumber's (based on current Query).
  def index_collection_number
    query = find_or_create_query(:CollectionNumber, by: params[:by])
    show_selected_collection_numbers(query, id: params[:id].to_s,
                                            always_index: true)
  end

  # Show list of collection_numbers.
  def index
    store_location
    query = create_query(:CollectionNumber, :all)
    show_selected_collection_numbers(query)
  end

  alias_method :list_collection_numbers, :index

  # Display list of CollectionNumbers whose text matches a string pattern.
  def collection_number_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (@collection_number = CollectionNumber.safe_find(pattern))
      # redirect_to(action: :show, id: @collection_number.id)
      redirect_to collection_number_path(@collection_number.id)
    else
      query = create_query(:CollectionNumber, :pattern_search, pattern: pattern)
      show_selected_collection_numbers(query)
    end
  end

  def observation_index
    store_location
    query = create_query(:CollectionNumber, :for_observation,
                         observation: params[:id].to_s)
    @links = [
      # [:show_object.l(type: :observation),
      #  Observation.show_link_args(params[:id])],
      # [:create_collection_number.l,
      #  { action: :create_collection_number, id: params[:id] }]
      [ :show_object.l(type: :observation),
                observation_path(id: params[:id])],
      [ :create_collection_number.l,
                new_collection_number_path(id: params[:id])]
    ]
    show_selected_collection_numbers(query, always_index: true)
  end

  def show
    store_location
    pass_query_params
    @canonical_url = CollectionNumber.show_url(params[:id])
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
  end

  alias_method :show_collection_number, :show

  def show_next
    redirect_to_next_object(:next, CollectionNumber, params[:id].to_s)
  end

  alias_method :next_collection_number, :show_next

  def show_prev
    redirect_to_next_object(:prev, CollectionNumber, params[:id].to_s)
  end

  alias_method :prev_collection_number, :show_prev

  def new
    store_location
    pass_query_params
    @layout = calc_layout_params
    @observation = find_or_goto_index(Observation, params[:id])
    return unless @observation

    @back_object = @observation
    return unless make_sure_can_edit!(@observation)

    @collection_number =
      CollectionNumber.new(whitelisted_collection_number_params)

    redirect_back_or_default("/") unless @collection_number
  end

  alias_method :create_collection_number, :new

  def create
    store_location
    pass_query_params
    build_collection_number
  end

  alias_method :post_create_collection_number, :create

  def edit
    store_location
    pass_query_params
    @layout = calc_layout_params
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
    return unless @collection_number

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!(@collection_number)
  end

  alias_method :edit_collection_number, :edit

  def update
    store_location
    pass_query_params
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
    save_edits
  end

  alias_method :post_edit_collection_number, :update

  def remove_observation
    pass_query_params
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
    return unless @collection_number

    @observation = find_or_goto_index(Observation, params[:obs])
    return unless @observation
    return unless make_sure_can_delete!(@collection_number)

    @collection_number.remove_observation(@observation)
    # redirect_with_query(@observation.show_link_args)
    redirect_to observation_path(@observation.id, q: get_query_param)
  end

  def destroy
    pass_query_params
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
    return unless @collection_number
    return unless make_sure_can_delete!(@collection_number)

    @collection_number.destroy
    # redirect_with_query(action: :index_collection_number)
    redirect_to collection_number_index_collection_number_path(
      q: get_query_param
    )
  end

  alias_method :destroy_collection_number, :destroy

  ##############################################################################

  private

  def show_selected_collection_numbers(query, args = {})
    args = {
      action: :index,
      letters: "collection_numbers.name",
      num_per_page: 100
    }.merge(args)

    @links ||= []

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["name",       :sort_by_name.t],
      ["number",     :sort_by_number.t],
      ["created_at", :sort_by_created_at.t],
      ["updated_at", :sort_by_updated_at.t]
    ]

    show_index_of_objects(query, args)
  end

  def build_collection_number
    normalize_parameters
    if @collection_number.name.blank?
      flash_error(:create_collection_number_missing_name.t)
      return
    elsif @collection_number.number.blank?
      flash_error(:create_collection_number_missing_number.t)
      return
    elsif name_and_number_free?
      @collection_number.save
      @collection_number.add_observation(@observation)
    else
      flash_warning(:edit_collection_number_already_used.t) if
        @other_number.observations.any?
      @other_number.add_observation(@observation)
      @collection_number = @other_number
    end
    redirect_to_observation_or_collection_number
  end

  def save_edits
    old_format_name = @collection_number.format_name
    @collection_number.attributes = whitelisted_collection_number_params
    normalize_parameters
    if @collection_number.name.blank?
      flash_error(:create_collection_number_missing_name.t)
      return
    elsif @collection_number.number.blank?
      flash_error(:create_collection_number_missing_number.t)
      return
    elsif name_and_number_free?
      @collection_number.save
      @collection_number.change_corresponding_herbarium_records(old_format_name)
    else
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
    end
    redirect_to_observation_or_collection_number
  end

  def whitelisted_collection_number_params
    return {} unless params[:collection_number]

    params.require(:collection_number).permit(:name, :number, :id)
  end

  def make_sure_can_edit!(obj)
    return true if in_admin_mode? || obj.can_edit?

    flash_error :permission_denied.t
    redirect_to_observation_or_collection_number
    false
  end

  def make_sure_can_delete!(collection_number)
    return true if collection_number.can_edit? || in_admin_mode?

    flash_error(:permission_denied.t)
    # redirect_to(collection_number.show_link_args)
    redirect_to collection_number_path(collection_number.id)
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

      @back_object = if @collection_number.observations.count == 1
                       @collection_number.observations.first
                     else
                       @collection_number
                     end
    end
  end

  def redirect_to_observation_or_collection_number
    if @back_object
      # redirect_with_query(@back_object.show_link_args)
      redirect_to object_path(@back_object, q: get_query_param)
    else
      # redirect_with_query(action: :index_collection_number,
      #                     id: @collection_number.id)
      redirect_to collection_number_index_collection_number_path(
        @collection_number.id,
        q: get_query_param
      )
    end
  end
end
