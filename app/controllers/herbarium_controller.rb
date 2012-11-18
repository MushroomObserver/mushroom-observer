class HerbariumController < ApplicationController
  before_filter :login_required, :except => [
    :show_herbarium,
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
  
  def name_in_use(new_name)
    if Herbarium.find_by_name(new_name)
      flash_error(:create_herbarium_duplicate_name.l(:name => new_name))
      true
    end
  end
  
  def create_herbarium # :norobots:
    if request.method == :post
      if !name_in_use(params[:herbarium][:name])
        place_name = params[:herbarium][:place_name].to_s
        location = Location.find_by_name_or_reverse_name(place_name)
        params[:herbarium][:location_id] = location.id if location
        herbarium = Herbarium.new(params[:herbarium])
        if herbarium.email.empty?
          flash_error(:create_herbarium_missing_email.l)
        else
          herbarium.curators.push(@user)
          herbarium.save
          if !location and !place_name.empty?
            flash_notice(:herbarium_must_define_location.t)
            redirect_to(:controller => 'location', :action => 'create_location',
                        :where => place_name, :set_herbarium => herbarium.id)
          else
            redirect_to(:action => 'show_herbarium', :id => herbarium.id)
          end
        end
      end
    end
  end

  def modify_herbarium(params, herbarium)
    calc_destination
  end
  
  def edit_herbarium # :norobots:
    @herbarium = Herbarium.find(params[:id])
    if request.method == :post
      new_name = params[:herbarium][:name]
      if (@herbarium.name != new_name) and !name_in_use(new_name)
        place_name = params[:herbarium][:place_name].to_s
        location = Location.find_by_name_or_reverse_name(place_name)
        params[:herbarium][:location_id] = location ? location.id : nil
        @herbarium.attributes = params[:herbarium]
        if @herbarium.email.empty?
          flash_error(:create_herbarium_missing_email.l)
        else
          @herbarium.save
          if !location and !place_name.empty?
            flash_notice(:herbarium_must_define_location.t)
            redirect_to(:controller => 'location', :action => 'create_location',
                        :where => place_name, :set_herbarium => @herbarium.id)
          else
            redirect_to(:action => 'show_herbarium', :id => @herbarium.id)
          end
        end
      end
    end
  end
end
