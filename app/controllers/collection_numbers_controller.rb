# frozen_string_literal: true

# Controls viewing and modifying collection numbers.
class CollectionNumbersController < ApplicationController
  before_action :login_required
  # except: [
  #   :index,
  #   :index_collection_number,
  #   :list_collection_numbers,
  #   :collection_number_search,
  #   :observation_index,
  #   :show
  # ]
  before_action :pass_query_params, except: :index
  before_action :store_location, except: [:index, :destroy]

  def index # rubocop:disable Metrics/AbcSize
    if params[:pattern].present? # rubocop:disable Style/GuardClause
      collection_number_search and return
    elsif params[:observation_id].present?
      observation_index and return
    elsif params[:by].present? || params[:q].present? || params[:id].present?
      index_collection_number and return
    else
      list_collection_numbers and return
    end
  end

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
  end

  def create
    set_ivars_for_new
    return unless @observation

    @back_object = @observation
    return unless make_sure_can_edit!(@observation)

    create_collection_number
  end

  def edit
    set_ivars_for_edit
    return unless @collection_number

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!(@collection_number)
  end

  def update
    set_ivars_for_edit
    return unless @collection_number

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!(@collection_number)

    update_collection_number
  end

  def destroy
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
    return unless @collection_number
    return unless make_sure_can_delete!(@collection_number)

    @collection_number.destroy
    redirect_with_query(action: :index)
  end

  ##############################################################################

  private

  # Displays matrix of selected CollectionNumber's (based on current Query).
  def index_collection_number
    query = find_or_create_query(:CollectionNumber, by: params[:by])
    show_selected_collection_numbers(query, id: params[:id].to_s,
                                            always_index: true)
  end

  # Show list of collection_numbers.
  def list_collection_numbers
    store_location
    query = create_query(:CollectionNumber, :all)
    show_selected_collection_numbers(query)
  end

  # Display list of CollectionNumbers whose text matches a string pattern.
  def collection_number_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (collection_number = CollectionNumber.safe_find(pattern))
      redirect_to(action: :show, id: collection_number.id)
    else
      query = create_query(:CollectionNumber, :pattern_search, pattern: pattern)
      show_selected_collection_numbers(query)
    end
  end

  def observation_index
    store_location
    query = create_query(:CollectionNumber, :for_observation,
                         observation: params[:observation_id].to_s)
    @links = [
      [:show_object.l(type: :observation),
       observation_path(params[:observation_id])],
      [:create_collection_number.l,
       new_collection_number_path(id: params[:observation_id])]
    ]
    show_selected_collection_numbers(query, always_index: true)
  end

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

  def set_ivars_for_new
    @layout = calc_layout_params
    @observation = find_or_goto_index(Observation, params[:observation_id])
  end

  def set_ivars_for_edit
    @layout = calc_layout_params
    @collection_number = find_or_goto_index(CollectionNumber, params[:id])
  end

  def create_collection_number
    @collection_number =
      CollectionNumber.new(whitelisted_collection_number_params)
    normalize_parameters
    return if check_for_form_errors?

    if name_and_number_free?
      @collection_number.save
      @collection_number.add_observation(@observation)
    else
      flash_warning(:edit_collection_number_already_used.t) if
        @other_number.observations.any?
      @other_number.add_observation(@observation)
      @collection_number = @other_number
    end
    redirect_to_observation_or_object(@collection_number)
  end

  def update_collection_number
    old_format_name = @collection_number.format_name
    @collection_number.attributes = whitelisted_collection_number_params
    normalize_parameters
    return if check_for_form_errors?

    if name_and_number_free?
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

    redirect_to_observation_or_object(@collection_number)
  end

  def check_for_form_errors?
    redirect_params = case action_name # this is a rails var
                      when "create"
                        { action: :new }
                      when "update"
                        { action: :edit }
                      end
    redirect_params = redirect_params.merge({ back: @back }) if @back.present?

    if @collection_number.name.blank?
      flash_error(:create_collection_number_missing_name.t)
      redirect_to(redirect_params) and return true
    elsif @collection_number.number.blank?
      flash_error(:create_collection_number_missing_number.t)
      redirect_to(redirect_params) and return true
    end
    false
  end

  def whitelisted_collection_number_params
    return {} unless params[:collection_number]

    params.require(:collection_number).permit(:name, :number)
  end

  def make_sure_can_edit!(obj)
    return true if in_admin_mode? || obj.can_edit?

    flash_error(:permission_denied.t)
    redirect_to_observation_or_object(@collection_number)
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

      @back_object = if @collection_number.observations.count == 1
                       @collection_number.observations.first
                     else
                       @collection_number
                     end
    end
  end
end
