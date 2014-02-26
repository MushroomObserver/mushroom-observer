class SpecimenController < ApplicationController
  before_filter :login_required, :except => [
    :specimen_search,
    :list_specimens,
    :show_specimen,
    :herbarium_index,
    :observation_index,
  ]
  
  # Display list of Specimens whose text matches a string pattern.
  def specimen_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) and
       (specimen = Specimen.safe_find(pattern))
      redirect_to(:action => 'show_specimen', :id => specimen.id)
    else
      query = create_query(:Specimen, :pattern_search, :pattern => pattern)
      show_selected_specimens(query)
    end
  end

  # Show selected list of specimens.
  def show_selected_specimens(query, args={})
    args = {
      :action => :list_specimens,
      :letters => 'specimens.name',
      :num_per_page => 10,
    }.merge(args)

    @links ||= []

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name',        :sort_by_title.t],
      ['created_at',  :sort_by_created_at.t],
      ['updated_at',  :sort_by_updated_at.t],
    ]

    args[:letters] = 'herbarium_label'
    
    show_index_of_objects(query, args)
  end

  # Show list of specimens.
  def list_specimens # :nologin:
    query = create_query(:Specimen, :all, :by => :herbarium_label)
    show_selected_specimens(query)
  end

  def show_specimen  # :nologin:
    @specimen = Specimen.find(params[:id].to_s)
    @layout = calc_layout_params
  end

  def herbarium_index # :nologin:
    store_location
    herbarium = Herbarium.find(params[:id].to_s)
    @specimens = herbarium ? herbarium.specimens : []
    @subject = herbarium.name
    if !calc_specimen_index_redirect(@specimens)
      flash_warning(:herbarium_index_no_specimens.t)
      redirect_to(:controller => 'herbarium', :action => 'show_herbarium', :id => params[:id].to_s)
    end
  end
  
  def calc_specimen_index_redirect(specimens)
    count = specimens.count
    if count != 0
      if count == 1
        redirect_to(:action => 'show_specimen', :id => specimens[0].id)
      else
        render(:action => 'specimen_index')
      end
    end
  end

  def observation_index # :nologin:
    store_location
    observation = Observation.find(params[:id].to_s)
    @specimens = observation ? observation.specimens : []
    @subject = observation.format_name
    if !calc_specimen_index_redirect(@specimens)
      flash_warning(:observation_index_no_specimens.t)
      redirect_to(:controller => 'observer', :action => 'show_observation', :id => params[:id].to_s)
    end
  end
  
  def add_specimen
    @observation = Observation.find(params[:id].to_s)
    @layout = calc_layout_params
    if @observation
      @herbarium_label = @observation.default_specimen_label
      if request.method == :post
        if valid_specimen_params(params[:specimen])
          build_specimen(params[:specimen], @observation)
        end
      end
    end
  end
 
  def valid_specimen_params(params)
    params[:herbarium_name] = params[:herbarium_name].strip_html
    params[:herbarium_label] = params[:herbarium_label].strip_html
    # has_curator_permission(params[:herbarium_name], @user) and
    !specimen_exists(params[:herbarium_name], params[:herbarium_label])
  end
  
  def has_curator_permission(herbarium_name, user)
    result = true
    herbarium = Herbarium.find_by_name(herbarium_name)
    if herbarium
      if not herbarium.curators.member?(user)
        flash_error(:add_specimen_not_a_curator.t(:herbarium_name => herbarium_name))
        result = false
      end
    end
    result
  end
  
  def specimen_exists(herbarium_name, herbarium_label)
    for s in Specimen.find_all_by_herbarium_label(herbarium_label)
      if s.herbarium.name == herbarium_name
        flash_error(:add_specimen_already_exists.strip_html(:name => herbarium_name, :label => herbarium_label))
        return true
      end
    end
    return false
  end
  
  def build_specimen(params, obs)
    params[:user] = @user
    new_herbarium = infer_herbarium(params)
    specimen = Specimen.new(params)
    specimen.add_observation(obs)
    specimen.save
    calc_specimen_redirect(params, new_herbarium, specimen) # Need appropriate redirect
  end
  
  def infer_herbarium(params)
    herbarium_name = params[:herbarium_name].to_s
    herbarium = Herbarium.find_by_name(herbarium_name)
    result = herbarium.nil?
    if result
      herbarium = Herbarium.new(herbarium_params(params))
      herbarium.curators.push(@user)
      herbarium.save
    end
    params[:herbarium] = herbarium
    result
  end
  
  def herbarium_params(params)
    {
      :name => params[:herbarium_name],
      :description => '',
      :email => @user.email,
      :mailing_address => "",
      :place_name => ""
    }
  end

  def calc_specimen_redirect(params, new_herbarium, specimen)
    if new_herbarium
      flash_notice(:herbarium_edit.t(:name => params[:herbarium_name]))
      redirect_to(:controller => 'herbarium', :action => 'edit_herbarium',
                  :id => specimen.herbarium_id)
    else
      redirect_to(:controller => 'observer', :action => 'show_observation', :id => specimen.observations[0].id)
    end
  end

  def delete_specimen
    specimen = Specimen.find(params[:id].to_s)
    herbarium_id = specimen.herbarium_id
    if can_delete?(specimen)
      specimen.clear_observations
      specimen.destroy
    end
    redirect_back_or_default(:action => 'herbarium_index', :id => herbarium_id)
  end

  def can_delete?(specimen)
    has_permission?(specimen, :delete_specimen_cannot_delete.l)
  end
  
  def has_permission?(specimen, error_message)
    result = (is_in_admin_mode? or specimen.can_edit?(@user))
    flash_error(error_message) if not result
    result
  end
  
  def edit_specimen # :norobots:
    @specimen = Specimen.find(params[:id].to_s)
    if can_edit?(@specimen)
      if (request.method == :post) and params[:specimen]
        if ok_to_update(@specimen, params[:specimen])
          update_specimen(@specimen, params[:specimen])
        end
      end
    else
      redirect_to(:action => 'show_specimen', :id => @specimen.id)
    end
  end
  
  def ok_to_update(specimen, params)
    params[:herbarium_label] = params[:herbarium_label].strip_html
    new_label = params[:herbarium_label]
    (specimen.herbarium_label == new_label) or label_free?(specimen.herbarium, new_label)
  end
  
  def label_free?(herbarium, new_label)
    result = herbarium.label_free?(new_label)
    flash_error(:edit_herbarium_duplicate_label.l(:herbarium_label => new_label, :herbarium_name => herbarium.name)) if !result
    result
  end
  
  def update_specimen(specimen, params)
    specimen.attributes = params
    specimen.save
    redirect_to(:action => 'show_specimen', :id => specimen.id)
  end
end
