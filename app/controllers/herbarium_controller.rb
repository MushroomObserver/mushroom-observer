class HerbariumController < ApplicationController
  before_filter :login_required, :except => [
    :show_herbarium,
    :show_specimen,
    :index,
  ]

  def show_herbarium  # :nologin:
    store_location
    @herbarium = Herbarium.find(params[:id])
  end

  def index # :nologin:
    store_location
    @herbaria = Herbarium.find(:all)
  end
  
  def create_herbarium # :norobots:
    if request.method == :post
      if valid_herbarium_params(params[:herbarium])
        build_herbarium(params[:herbarium])
      end
    end
  end
  
  def valid_herbarium_params(params)
    name_free?(params[:name]) and email_valid?(params[:email])
  end

  def name_free?(new_name)
    result = (Herbarium.find_by_name(new_name) == nil)
    flash_error(:create_herbarium_duplicate_name.l(:name => new_name)) if not result
    result
  end
  
  def email_valid?(email)
    result = (email and (email != ""))
    flash_error(:create_herbarium_missing_email.l) if not result
    result
  end
  
  def build_herbarium(params)
    infer_location(params)
    herbarium = Herbarium.new(params)
    herbarium.curators.push(@user)
    herbarium.save
    calc_herbarium_redirect(params, herbarium)
  end
  
  def infer_location(params)
    place_name = params[:place_name].to_s
    location = Location.find_by_name_or_reverse_name(place_name)
    params[:location_id] = location ? location.id : nil
  end

  def calc_herbarium_redirect(params, herbarium)
    if !herbarium.location and !params[:place_name].empty?
      flash_notice(:herbarium_must_define_location.t)
      redirect_to(:controller => 'location', :action => 'create_location',
                  :where => params[:place_name], :set_herbarium => herbarium.id)
    else
      redirect_to(:action => 'show_herbarium', :id => herbarium.id)
    end
  end
  
  def edit_herbarium # :norobots:
    @herbarium = Herbarium.find(params[:id])
    if user_is_curator?(@herbarium)
      if request.method == :post
        if ok_to_update(@herbarium, params[:herbarium])
          update_herbarium(@herbarium, params[:herbarium])
        end
      end
    else
      redirect_to(:action => 'show_herbarium', :id => @herbarium.id)
    end
  end
  
  def ok_to_update(herbarium, params)
    new_name = params[:name]
    return (((herbarium.name == new_name) or name_free?(new_name)) and email_valid?(params[:email]))
  end

  def user_is_curator?(herbarium)
    result = herbarium.is_curator?(@user)
    flash_error(:edit_herbarium_non_curator.l) if not result
    result
  end

  def update_herbarium(herbarium, params) # Hmmm, should this be a method on Herbarium?
    infer_location(params)
    @herbarium.attributes = params
    herbarium.save
    calc_herbarium_redirect(params, herbarium)
  end
  
  def add_specimen
    @observation = find_observation(params[:id])
    @layout = calc_layout_params
    if @observation
      @herbarium_label = "#{@observation.name.text_name} [#{@observation.id}]"
      @herbarium_name = @user.preferred_herbarium_name
      if request.method == :post
        if valid_specimen_params(params[:specimen])
          build_specimen(params[:specimen], @observation)
        end
      end
    end
  end
  
  def find_observation(id)
    result = Observation.safe_find(id)
    if result.nil?
      flash_error(:add_specimen_observation_required.t)
      redirect_to(:controller => 'observer', :action => 'observations_by_user',
                  :id => @user.id)
    end
    result
  end
  
  def valid_specimen_params(params)
    !specimen_exists(params[:herbarium_name], params[:herbarium_label])
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
    specimen.observations.push(obs)
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
      redirect_to(:action => 'edit_herbarium',
                  :id => specimen.herbarium_id)
    else
      redirect_to(:controller => 'observer', :action => 'show_observation', :id => specimen.observations[0].id)
    end
  end
  
  def show_specimen  # :nologin:
    store_location
    @specimen = Specimen.find(params[:id])
  end
  
end
