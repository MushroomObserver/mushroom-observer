class HerbariumController < ApplicationController
  before_filter :login_required, :except => [
    :herbarium_search,
    :list_herbariums,
    :show_herbarium,
    :index,
  ]

  # Display list of Herbaria whose text matches a string pattern.
  def herbarium_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) and
       (herbarium = Herbarium.safe_find(pattern))
      redirect_to(:action => 'show_herbarium', :id => herbarium.id)
    else
      query = create_query(:Herbarium, :pattern_search, :pattern => pattern)
      show_selected_herbaria(query)
    end
  end

  # Show selected list of herbaria.
  def show_selected_herbaria(query, args={})
    args = {
      :action => :list_herbaria,
      :letters => 'herbaria.name',
      :num_per_page => 10,
    }.merge(args)

    @links ||= []

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name',     :sort_by_title.t],
      ['created',  :sort_by_created.t],
      ['modified', :sort_by_modified.t],
    ]

    show_index_of_objects(query, args)
  end

  # Show list of herbaria.
  def list_herbariums # :nologin:
    query = create_query(:Herbarium, :all, :by => :name)
    show_selected_herbaria(query)
  end

  def show_herbarium  # :nologin:
    store_location
    @herbarium = Herbarium.find(params[:id])
    if request.method == :post
      herbarium = Herbarium.find(params[:id])
      login = params[:curator][:name].sub(/ <.*/, '')
      user = User.find_by_login(login)
      if user
        herbarium.add_curator(user)
      else
        flash_error(:show_herbarium_no_user.t(:login => login))
      end
    end
  end

  def delete_curator
    herbarium = Herbarium.find(params[:id])
    user = User.find(params[:user])
    if herbarium.is_curator?(@user)
      if herbarium.is_curator?(user)
        herbarium.delete_curator(user)
      else
        flash_error(:delete_curator_they_not_curator.t(:login => user.login))
      end
    else
      flash_error(:delete_curator_you_not_curator.t)
    end
    redirect_to(:action => :show_herbarium, :id => params[:id])
  end
  
  def index # :nologin:
    store_location
    @herbaria = Herbarium.find(:all)
  end
  
  def create_herbarium # :norobots:
    name = @user.personal_herbarium
    @herbarium_name = (@user.personal_herbarium.nil?) ? @user.preferred_herbarium_name : ""
    if request.method == :post
      if valid_herbarium_params(params[:herbarium])
        build_herbarium(params[:herbarium])
      end
    end
  end
  
  def valid_herbarium_params(params)
    params[:name] = params[:name].strip_html
    name_free?(params[:name]) and email_valid?(params[:email])
  end

  def name_free?(new_name)
    result = (Herbarium.find_by_name(new_name) == nil)
    flash_error(:create_herbarium_duplicate_name.l(:name => new_name)) if not result
    result
  end
  
  def email_valid?(email)
    result = (email and (email != "") and (email == email.strip_html))
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
    params[:place_name] = params[:place_name] ? params[:place_name].strip_html : ""
    location = Location.find_by_name_or_reverse_name(params[:place_name])
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
    new_name = params[:name].strip_html
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
end
