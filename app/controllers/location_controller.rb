class LocationController < ApplicationController
  before_filter :login_required, :except => ([:list_place_names])

  def list_place_names
    query = "select o.where, o.location_id, count(1) from observations o group by o.where, o.location_id order by o.where"
    @data = Observation.connection.select_all(query)
  end

  def create_location
    @where = params[:where]
    @id = params[:id]
  end
  
  def update_observations_by_where(location, where)
    if where
      observations = Observation.find_all_by_where(where)
      for o in observations
        unless o.location_id
          o.location = location
          o.where = nil
          o.save
        end
      end
    end
  end

  def construct_location
    if verify_user()
      start_name = params[:where]
      start_id = params[:id]
      
      # Look for an existing location by this exact name
      action = 'list_place_names'
      location = Location.find_by_display_name(params[:location][:display_name])
      unless location # Build one if needed
        location = Location.new(params[:location])
        location.user = session['user']
        location.version = 0
        if location.save()
          flash[:notice] = 'Location was successfully added.'
        else
          flash[:notice] = sprintf('Unable to save location: %s', location.display_name)
          location = nil
          action = 'create_location' # Do values propagate on fail?  Logic comes from comment so it should be reviewed as well
        end
      end
      if location # Apply this one to the old observations
        if params[:previous]
          if params[:previous][:id] == ''
            update_observations_by_where(location, params[:previous][:where])
          end
        end
      end
      redirect_to(:action => action)
    end
  end
  
  def show_location
    store_location
    id = params[:id]
    @location = Location.find(id)
    query = "select o.id, o.when, o.modified, o.when, o.thumb_image_id, o.where, o.location_id," +
            " u.name, u.login, n.observation_name from observations o, users u, names n" +
            " where o.location_id = %s and o.user_id = u.id and n.id = o.name_id order by n.text_name, o.when desc"
    @data = Location.connection.select_all(query % params[:id])
  end
  
  def edit_location
    store_location
    @location = Location.find(params[:id])
  end
  
  def update_location
    @location = Location.find(params[:id])
    if verify_user() # Even though edit makes this check, avoid bad guys going directly
      if @location.update_attributes(params[:location])
        if @location.save
          flash[:notice] = 'Location was successfully updated.'
        end
        redirect_to :action => 'show_location', :id => @location
      else
        render :action => 'edit_location'
      end
    else
      render :action => 'show_location'
    end
  end
end
