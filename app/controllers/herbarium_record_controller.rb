class HerbariumRecordController < ApplicationController
  before_action :login_required, except: [
    :index_herbarium_record,
    :herbarium_record_search,
    :list_herbarium_records,
    :show_herbarium_record,
    :herbarium_index,
    :observation_index
  ]

  # Displays matrix of selected HerbariumRecord's (based on current Query).
  def index_herbarium_record # :nologin: :norobots:
    query = find_or_create_query(:HerbariumRecord, by: params[:by])
    show_selected_herbarium_records(query, id: params[:id].to_s,
                                    always_index: true)
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

  # Show selected list of herbarium_records.
  def show_selected_herbarium_records(query, args = {})
    args = {
      action: :list_herbarium_records,
      letters: "herbarium_records.name",
      num_per_page: 10
    }.merge(args)

    @links ||= []

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["name",        :sort_by_title.t],
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t]
    ]

    args[:letters] = "herbarium_label"

    show_index_of_objects(query, args)
  end

  # Show list of herbarium_records.
  def list_herbarium_records # :nologin:
    query = create_query(:HerbariumRecord, :all, by: :herbarium_label)
    show_selected_herbarium_records(query)
  end

  def show_herbarium_record  # :nologin:
    @herbarium_record = HerbariumRecord.find(params[:id].to_s)
    @layout = calc_layout_params
  end

  def herbarium_index # :nologin:
    store_location
    herbarium = Herbarium.find(params[:id].to_s)
    @herbarium_records = herbarium ? herbarium.herbarium_records : []
    @subject = herbarium.name
    unless calc_herbarium_record_index_redirect(@herbarium_records)
      flash_warning(:herbarium_index_no_herbarium_records.t)
      redirect_to(controller: :herbarium, action: :show_herbarium,
                  id: params[:id].to_s)
    end
  end

  def calc_herbarium_record_index_redirect(herbarium_records)
    count = herbarium_records.count
    if count != 0
      if count == 1
        redirect_to(action: :show_herbarium_record, id: herbarium_records[0].id)
      else
        render(action: :herbarium_record_index)
      end
    end
  end

  def observation_index # :nologin:
    store_location
    observation = Observation.find(params[:id].to_s)
    @herbarium_records = observation ? observation.herbarium_records : []
    @subject = observation.format_name
    unless calc_herbarium_record_index_redirect(@herbarium_records)
      flash_warning(:observation_index_no_herbarium_records.t)
      redirect_to(controller: :observer, action: :show_observation,
                  id: params[:id].to_s)
    end
  end

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

  def edit_herbarium_record # :norobots:
    @herbarium_record = HerbariumRecord.find(params[:id].to_s)
    redirect_to(action: :show_herbarium_record,
                id: @herbarium_record.id) unless can_edit?(@herbarium_record)

    if (request.method == "POST") && params[:herbarium_record]
      if ok_to_update(@herbarium_record, params[:herbarium_record])
        update_herbarium_record(@herbarium_record, params[:herbarium_record])
      end
    end
  end

  def ok_to_update(herbarium_record, params)
    params[:herbarium_label] = params[:herbarium_label].strip_html
    new_label = params[:herbarium_label]
    (herbarium_record.herbarium_label == new_label) || label_free?(herbarium_record.herbarium,
                                                           new_label)
  end

  def label_free?(herbarium, new_label)
    result = herbarium.label_free?(new_label)
    flash_error(:edit_herbarium_duplicate_label.l(herbarium_label: new_label,
                                                  herbarium_name: herbarium.name)) unless result
    result
  end

  def update_herbarium_record(herbarium_record, _params)
    herbarium_record.attributes = whitelisted_herbarium_record_params
    herbarium_record.save
    redirect_to(action: :show_herbarium_record, id: herbarium_record.id)
  end

  ##############################################################################

  private

  def whitelisted_herbarium_record_params
    params.require(:herbarium_record).permit(:when, :notes, :herbarium_label)
  end
end
