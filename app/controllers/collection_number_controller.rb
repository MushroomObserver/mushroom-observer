class CollectionNumberController < ApplicationController
  before_action :login_required, except: [
    :index_collection_number,
    :list_collection_numbers,
    :collection_number_search,
    :observation_index,
    :show_collection_number
  ]

  # ----------------------------
  #  Indexes
  # ----------------------------

  # Displays matrix of selected CollectionNumber's (based on current Query).
  def index_collection_number # :nologin: :norobots:
    query = find_or_create_query(:CollectionNumber, by: params[:by])
    show_selected_collection_numbers(query, id: params[:id].to_s,
                                           always_index: true)
  end

  # Show list of collection_numbers.
  def list_collection_numbers # :nologin:
    query = create_query(:CollectionNumber, :all)
    show_selected_collection_numbers(query)
  end

  # Display list of CollectionNumbers whose text matches a string pattern.
  def collection_number_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (collection_number = CollectionNumber.safe_find(pattern))
      redirect_to(action: :show_collection_number, id: collection_number.id)
    else
      query = create_query(:CollectionNumber, :pattern_search, pattern: pattern)
      show_selected_collection_numbers(query)
    end
  end

  def observation_index # :nologin:
    store_location
    query = create_query(:CollectionNumber, :for_observation,
                         observation: params[:id].to_s)
    @links = [
      [:show_object.l(type: :observation),
        { controller: :observer, action: :show_observation, id: params[:id] }],
      [:add_collection_number.l,
        { action: :add_collection_number, id: params[:id] }]
    ]
    show_selected_collection_numbers(query, always_index: true)
  end

  # Show selected list of collection_numbers.
  def show_selected_collection_numbers(query, args = {})
    args = {
      action: :list_collection_numbers,
      letters: "collection_numbers.name",
      num_per_page: 10
    }.merge(args)

    @links ||= []
    @links << [:create_herbarium.l,
                { controller: :herbarium, action: :create_herbarium }]

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["herbarium_name",  :sort_by_herbarium_name.t],
      ["herbarium_label", :sort_by_herbarium_label.t],
      ["created_at",      :sort_by_created_at.t],
      ["updated_at",      :sort_by_updated_at.t]
    ]

    args[:letters] = "herbarium_label"

    show_index_of_objects(query, args)
  end

  # ----------------------------
  #  Show record
  # ----------------------------

  def show_collection_number  # :nologin:
    pass_query_params
    @collection_number = CollectionNumber.find(params[:id].to_s)
  end

  # ----------------------------
  #  Create record
  # ----------------------------

  def add_collection_number
    pass_query_params
    @observation     = Observation.find(params[:id].to_s)
    @layout          = calc_layout_params
    @herbarium_name  = @user.preferred_herbarium_name
    @herbarium_label = @observation.default_specimen_label
    if request.method == "POST"
      save_collection_number(@observation, params[:collection_number])
      redirect_to(action: :observation_index, id: @observation.id)
    end
  end

  def save_collection_number(obs, params)
    @herbarium_name  = params[:herbarium_name].to_s.strip_html.strip_squeeze
    @herbarium_label = params[:herbarium_label].to_s.strip_html.strip_squeeze
    @herbarium       = lookup_herbarium(@herbarium_name)
    return unless @herbarium
    collection_number = CollectionNumber.where(
      herbarium:       @herbarium,
      herbarium_label: @herbarium_label
    ).first
    if !collection_number
      collection_number = CollectionNumber.create(
        herbarium:       @herbarium,
        herbarium_label: @herbarium_label
      )
    elsif collection_number.can_edit?
      flash_warning :add_collection_number_label_already_used.t(
        herbarium_name:  @herbarium.name,
        herbarium_label: @herbarium_label
      )
    else
      flash_warning :add_collection_number_label_already_used_by_someone_else.t(
        herbarium_name:  @herbarium.name,
        herbarium_label: @herbarium_label
      )
      return
    end
    collection_number.add_observation(obs)
  end

  def lookup_herbarium(herbarium_name)
    return if herbarium_name.blank?
    herbarium = Herbarium.where(name: herbarium_name).first
    return herbarium unless herbarium.nil?
    if herbarium_name != @user.personal_herbarium_name
      flash_warning(:form_observations_create_herbarium_separately.t)
      return
    end
    Herbarium.create(
      name:          herbarium_name,
      email:         @user.email,
      personal_user: @user,
      curators:      [@user]
    )
  end

  # ----------------------------
  #  Edit record
  # ----------------------------

  def edit_collection_number # :norobots:
    pass_query_params
    @collection_number = CollectionNumber.safe_find(params[:id].to_s)
    if !@collection_number
      redirect_to(action: :list_collection_numbers)
    elsif !can_edit_record?(@collection_number)
      redirect_to(action: :show_collection_number, id: @collection_number.id)
    elsif request.method == "GET"
      @herbarium_name = @collection_number.herbarium.name
    elsif request.method == "POST"
      post_edit_collection_number
    end
  end

  def post_edit_collection_number
    rec_params = params[:collection_number]
    if rec_params
      return unless validate_new_herbarium!(rec_params)
      return unless validate_new_label!(rec_params)
      return unless validate_new_notes!(rec_params)
      update_collection_number
    end
    remove_observations
    add_observations
  end

  def can_edit_record?(rec)
    return true if in_admin_mode?
    return true if rec.herbarium.curators.include?(@user)
    return true if rec.observations.any?(&:has_edit_permission?)
    return true if rec.user == @user
    flash_error(:runtime_no_update.l(type: :collection_number))
    false
  end

  def validate_new_herbarium!(params)
    @herbarium_name = params[:herbarium_name].to_s.strip_squeeze
    @new_herbarium = Herbarium.where(name: @herbarium_name).first
  end

  def validate_new_label!(params)
    new_label = params[:herbarium_label].to_s.strip_html.strip_squeeze
    @collection_number.herbarium_label = new_label
    if new_label.blank?
      flash_error(:edit_collection_number_label_blank.t)
      return false
    end
    make_sure_label_free!(@new_herbarium, new_label)
  end

  def make_sure_label_free!(herbarium, new_label)
    match = CollectionNumber.where(herbarium: herbarium,
                                  herbarium_label: new_label).first
    return true if !match || match == @collection_number
    flash_error(:edit_herbarium_duplicate_label.l(
      herbarium_label: new_label,
      herbarium_name: herbarium.name)
    )
    false
  end

  def validate_new_notes!(params)
    @collection_number.notes = params[:notes].to_s.strip
  end

  def update_collection_number
    old_herbarium = @collection_number.herbarium
    @collection_number.herbarium = @new_herbarium
    @collection_number.save
    @collection_number.notify_curators if old_herbarium != @new_herbarium
    redirect_to(action: :show_collection_number, id: @collection_number.id)
  end

  def remove_observations
    @collection_number.observations.each do |obs|
      next if params[:"remove_observation_#{obs.id}"] != "1"
      if can_add_or_remove_observation?(obs)
        @collection_number.observations.delete(obs)
      else
        flash_error(:edit_collection_number_cant_add_or_remove.t(id: obs.id))
      end
    end
  end

  def add_observations
    params[:add_observations].to_s.strip_squeeze.split.each do |id|
      obs = Observation.safe_find(id)
      if obs.nil?
        flash_error(:edit_collection_number_add_observation_not_found.t(id: id))
      elsif !can_add_or_remove_observation?(obs)
        flash_error(:edit_collection_number_cant_add_or_remove.t(id: obs.id))
      else
        @collection_number.observations << obs
        obs.update_attributes(specimen: true) \
          if obs.has_edit_permission? && !obs.specimen
      end
    end
  end

  def can_add_or_remove_observation?(obs)
    return true if in_admin_mode?
    return true if @collection_number.herbarium.curators.include?(@user)
    return true if obs.has_edit_permission?
    false
  end

  # ----------------------------
  #  Delete record
  # ----------------------------

  def delete_collection_number
    collection_number = CollectionNumber.find(params[:id].to_s)
    herbarium_id = collection_number.herbarium_id
    if can_delete?(collection_number)
      collection_number.destroy
    end
    redirect_back_or_default(action: :herbarium_index, id: herbarium_id)
  end

  def can_delete?(collection_number)
    permission?(collection_number, :delete_collection_number_cannot_delete.l)
  end

  ##############################################################################

  private

  def whitelisted_collection_number_params
    params.require(:collection_number).permit(:name, :number)
  end
end
