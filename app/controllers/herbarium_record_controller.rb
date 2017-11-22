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
    @links = [:add_herbarium_record.l,
              { action: :add_herbarium_record, id: params[:id] }]
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
    @herbarium_record = HerbariumRecord.find(params[:id].to_s)
    @layout = calc_layout_params
  end

  # ----------------------------
  #  Create record
  # ----------------------------

  def add_herbarium_record
    @observation = Observation.find(params[:id].to_s)
    @layout = calc_layout_params
    @herbarium_name = @user.preferred_herbarium_name
    if @observation
      @herbarium_label = @observation.default_specimen_label
      if request.method == "POST"
        if valid_herbarium_record_params(params[:herbarium_record])
          build_herbarium_record(params[:herbarium_record], @observation)
        end
      end
    end
  end

  def valid_herbarium_record_params(params)
    params[:herbarium_name] = params[:herbarium_name].to_s.strip_html
    params[:herbarium_label] = params[:herbarium_label].strip_html
    # has_curator_permission(params[:herbarium_name], @user) and
    !herbarium_record_exists(params[:herbarium_name], params[:herbarium_label])
  end

  def has_curator_permission(herbarium_name, user)
    result = true
    herbarium = Herbarium.find_by_name(herbarium_name)
    if herbarium
      unless herbarium.curators.member?(user)
        flash_error(:add_herbarium_record_not_a_curator.t(herbarium_name: herbarium_name))
        result = false
      end
    end
    result
  end

  def herbarium_record_exists(herbarium_name, herbarium_label)
    for s in HerbariumRecord.where(herbarium_label: herbarium_label)
      if s.herbarium.name == herbarium_name
        flash_error(:add_herbarium_record_already_exists.strip_html(
                      name: herbarium_name, label: herbarium_label))
        return true
      end
    end
    false
  end

  def build_herbarium_record(params, obs)
    params[:user] = @user
    new_herbarium = infer_herbarium(params)
    herbarium_record = HerbariumRecord.new(whitelisted_herbarium_record_params)
    herbarium_record.herbarium_id = params[:herbarium].id
    herbarium_record.add_observation(obs)
    herbarium_record.save
    calc_herbarium_record_redirect(params, new_herbarium, herbarium_record) # redirect properly
  end

  def infer_herbarium(params)
    herbarium_name = params[:herbarium_name].to_s
    herbarium = Herbarium.find_by_name(herbarium_name)
    result = herbarium.nil?
    if result
      herbarium = Herbarium.new(herbarium_params(params))
      herbarium.personal_user = @user if herbarium.name ==
                                         @user.personal_herbarium_name
      herbarium.curators.push(@user)
      herbarium.save
    end
    params[:herbarium] = herbarium
    result
  end

  def herbarium_params(params)
    {
      name: params[:herbarium_name],
      description: "",
      email: @user.email,
      mailing_address: "",
      place_name: ""
    }
  end

  def calc_herbarium_record_redirect(params, new_herbarium, herbarium_record)
    if new_herbarium
      flash_notice(:herbarium_edit.t(name: params[:herbarium_name]))
      redirect_to(controller: :herbarium, action: :edit_herbarium,
                  id: herbarium_record.herbarium_id)
    else
      redirect_to(controller: :observer, action: :show_observation,
                  id: herbarium_record.observations[0].id)
    end
  end

  # ----------------------------
  #  Edit record
  # ----------------------------

  def edit_herbarium_record # :norobots:
    @herbarium_record = HerbariumRecord.safe_find(params[:id].to_s)
    if !@herbarium_record
      redirect_to(action: :list_herbarium_records)
    elsif !can_edit?(@herbarium_record)
      redirect_to(action: :show_herbarium_record, id: @herbarium_record.id)
    elsif request.method == "GET"
      @herbarium_name = @herbarium_record.herbarium.name
    elsif request.method == "POST" &&
          params[:herbarium_record] &&
          validate_new_herbarium!(params[:herbarium_record]) &&
          validate_new_label!(params[:herbarium_record]) &&
          validate_new_notes!(params[:herbarium_record])
      update_herbarium_record
    end
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
    return true if herbarium.label_free?(new_label)
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
