class HerbariumRecordController < ApplicationController
  before_action :login_required, except: [
    :list_herbarium_records,
    :index_herbarium_record,
    :herbarium_record_search,
    :herbarium_index,
    :observation_index,
    :show_herbarium_record
  ]

  # ----------------------------
  #  Indexes
  # ----------------------------

  # Displays matrix of selected HerbariumRecord's (based on current Query).
  def index_herbarium_record # :nologin: :norobots:
    query = find_or_create_query(:HerbariumRecord, by: params[:by])
    show_selected_herbarium_records(query, id: params[:id].to_s,
                                           always_index: true)
  end

  # Show list of herbarium_records.
  def list_herbarium_records # :nologin:
    query = create_query(:HerbariumRecord, :all, by: :herbarium_label)
    show_selected_herbarium_records(query)
  end

  # Display list of HerbariumRecords whose text matches a string pattern.
  def herbarium_record_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (herbarium_record = HerbariumRecord.safe_find(pattern))
      redirect_to(action: :show_herbarium_record, id: herbarium_record.id)
    else
      query = create_query(:HerbariumRecord, :pattern_search, pattern: pattern)
      show_selected_herbarium_records(query)
    end
  end

  def herbarium_index # :nologin:
    store_location
    query = create_query(:HerbariumRecord, :in_herbarium,
                         herbarium: params[:id].to_s, by: :herbarium_label)
    show_selected_herbarium_records(query, always_index: true)
  end

  def observation_index # :nologin:
    store_location
    query = create_query(:HerbariumRecord, :for_observation,
                         observation: params[:id].to_s, by: :herbarium_label)
    @links = [
      [:show_object.l(type: :observation),
        { controller: :observer, action: :show_observation, id: params[:id] }],
      [:add_herbarium_record.l,
        { action: :add_herbarium_record, id: params[:id] }]
    ]
    show_selected_herbarium_records(query, always_index: true)
  end

  # Show selected list of herbarium_records.
  def show_selected_herbarium_records(query, args = {})
    args = {
      action: :list_herbarium_records,
      letters: "herbarium_records.name",
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

  def show_herbarium_record  # :nologin:
    pass_query_params
    @herbarium_record = HerbariumRecord.find(params[:id].to_s)
    @layout = calc_layout_params
  end

  # ----------------------------
  #  Create record
  # ----------------------------

  def add_herbarium_record
    pass_query_params
    @observation     = Observation.find(params[:id].to_s)
    @layout          = calc_layout_params
    @herbarium_name  = @user.preferred_herbarium_name
    @herbarium_label = @observation.default_specimen_label
    if request.method == "POST"
      save_herbarium_record(@observation, params[:herbarium_record])
      redirect_to(action: :observation_index, id: @observation.id)
    end
  end

  def save_herbarium_record(obs, params)
    @herbarium_name  = params[:herbarium_name].to_s.strip_html.strip_squeeze
    @herbarium_label = params[:herbarium_label].to_s.strip_html.strip_squeeze
    @herbarium       = lookup_herbarium(@herbarium_name)
    return unless @herbarium
    herbarium_record = HerbariumRecord.where(
      herbarium:       @herbarium,
      herbarium_label: @herbarium_label
    ).first
    if !herbarium_record
      herbarium_record = HerbariumRecord.create(
        herbarium:       @herbarium,
        herbarium_label: @herbarium_label
      )
    elsif herbarium_record.can_edit?
      flash_warning :add_herbarium_record_label_already_used.t(
        herbarium_name:  @herbarium.name,
        herbarium_label: @herbarium_label
      )
    else
      flash_warning :add_herbarium_record_label_already_used_by_someone_else.t(
        herbarium_name:  @herbarium.name,
        herbarium_label: @herbarium_label
      )
      return
    end
    herbarium_record.add_observation(obs)
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

  def edit_herbarium_record # :norobots:
    pass_query_params
    @herbarium_record = HerbariumRecord.safe_find(params[:id].to_s)
    if !@herbarium_record
      redirect_to(action: :list_herbarium_records)
    elsif !can_edit_record?(@herbarium_record)
      redirect_to(action: :show_herbarium_record, id: @herbarium_record.id)
    elsif request.method == "GET"
      @herbarium_name = @herbarium_record.herbarium.name
    elsif request.method == "POST"
      post_edit_herbarium_record
    end
  end

  def post_edit_herbarium_record
    rec_params = params[:herbarium_record]
    if rec_params
      return unless validate_new_herbarium!(rec_params)
      return unless validate_new_label!(rec_params)
      return unless validate_new_notes!(rec_params)
      update_herbarium_record
    end
    remove_observations
    add_observations
  end

  def can_edit_record?(rec)
    return true if in_admin_mode?
    return true if rec.herbarium.curators.include?(@user)
    return true if rec.observations.any?(&:has_edit_permission?)
    return true if rec.user == @user
    flash_error(:runtime_no_update.l(type: :herbarium_record))
    false
  end

  def validate_new_herbarium!(params)
    @herbarium_name = params[:herbarium_name].to_s.strip_squeeze
    @new_herbarium = Herbarium.where(name: @herbarium_name).first
  end

  def validate_new_label!(params)
    new_label = params[:herbarium_label].to_s.strip_html.strip_squeeze
    @herbarium_record.herbarium_label = new_label
    if new_label.blank?
      flash_error(:edit_herbarium_record_label_blank.t)
      return false
    end
    make_sure_label_free!(@new_herbarium, new_label)
  end

  def make_sure_label_free!(herbarium, new_label)
    match = HerbariumRecord.where(herbarium: herbarium,
                                  herbarium_label: new_label).first
    return true if !match || match == @herbarium_record
    flash_error(:edit_herbarium_duplicate_label.l(
      herbarium_label: new_label,
      herbarium_name: herbarium.name)
    )
    false
  end

  def validate_new_notes!(params)
    @herbarium_record.notes = params[:notes].to_s.strip
  end

  def update_herbarium_record
    old_herbarium = @herbarium_record.herbarium
    @herbarium_record.herbarium = @new_herbarium
    @herbarium_record.save
    @herbarium_record.notify_curators if old_herbarium != @new_herbarium
    redirect_to(action: :show_herbarium_record, id: @herbarium_record.id)
  end

  def remove_observations
    @herbarium_record.observations.each do |obs|
      next if params[:"remove_observation_#{obs.id}"] != "1"
      if can_add_or_remove_observation?(obs)
        @herbarium_record.observations.delete(obs)
      else
        flash_error(:edit_herbarium_record_cant_add_or_remove.t(id: obs.id))
      end
    end
  end

  def add_observations
    params[:add_observations].to_s.strip_squeeze.split.each do |id|
      obs = Observation.safe_find(id)
      if obs.nil?
        flash_error(:edit_herbarium_record_add_observation_not_found.t(id: id))
      elsif !can_add_or_remove_observation?(obs)
        flash_error(:edit_herbarium_record_cant_add_or_remove.t(id: obs.id))
      else
        @herbarium_record.observations << obs
        obs.update_attributes(specimen: true) \
          if obs.has_edit_permission? && !obs.specimen
      end
    end
  end

  def can_add_or_remove_observation?(obs)
    return true if in_admin_mode?
    return true if @herbarium_record.herbarium.curators.include?(@user)
    return true if obs.has_edit_permission?
    false
  end

  # ----------------------------
  #  Delete record
  # ----------------------------

  def delete_herbarium_record
    herbarium_record = HerbariumRecord.find(params[:id].to_s)
    herbarium_id = herbarium_record.herbarium_id
    if can_delete?(herbarium_record)
      herbarium_record.destroy
    end
    redirect_back_or_default(action: :herbarium_index, id: herbarium_id)
  end

  def can_delete?(herbarium_record)
    permission?(herbarium_record, :delete_herbarium_record_cannot_delete.l)
  end

  ##############################################################################

  private

  def whitelisted_herbarium_record_params
    params.require(:herbarium_record).permit(:notes, :herbarium_label)
  end
end
