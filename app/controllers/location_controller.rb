class LocationController < ApplicationController
  before_filter :login_required, :except => ([:list_place_names, :show_location, :show_past_location])

  def list_place_names
    known_query = "select o.location_id, l.display_name, count(1) as cnt
      from observations o, locations l where o.location_id = l.id
      group by o.location_id, l.display_name order by l.display_name"
    @known_data = Observation.connection.select_all(known_query)
    undef_query = "select o.where, count(1) as cnt
      from observations o where o.location_id is NULL
      group by o.where order by cnt desc"
    @undef_data = Observation.connection.select_all(undef_query)
  end

  def create_location
    @where = params[:where]
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
      
      # Look for an existing location by this exact name
      action = 'list_place_names'
      id = nil
      
      # Look to see if the display name is already use.  If it is then just use that
      # location and ignore the other values.  Probably should be smarter with warnings
      # and merges and such...
      @location = Location.find_by_display_name(params[:location][:display_name])
      if @location # Build one if needed
        update_observations_by_where(@location, params[:previous][:where]) if params[:previous]
        redirect_to(:action => 'show_location', :id => @location)
      else
        @location = Location.new(params[:location])
        @location.created = Time.now
        @location.modified = @location.created
        @location.user = session['user']
        @location.version = 0
        if @location.save()
          flash[:notice] = 'Location was successfully added.'
          action = 'show_location'
          update_observations_by_where(@location, params[:previous][:where]) if params[:previous]
          redirect_to(:action => 'show_location', :id => @location)
        else
          flash[:notice] = sprintf('Unable to save location: %s', @location.display_name)
          render :action => 'create_location' # Do values propagate on fail?  Logic comes from comment so it should be reviewed as well
        end
      end
    end
  end

  def show_past_location
    store_location
    @past_location = PastLocation.find(params[:id])
    @other_versions = PastLocation.find(:all, :conditions => "location_id = %s" % @past_location.location_id, :order => "version desc")
    @map = make_map([@past_location])
    @header = "#{GMap.header}\n#{@map.to_html}"
  end

  def show_location
    store_location
    id = params[:id]
    @location = Location.find(id)
    # query = "select o.id, o.when, o.modified, o.when, o.thumb_image_id, o.where, o.location_id," +
    #         " u.name, u.login, n.observation_name from observations o, users u, names n" +
    #         " where o.location_id = %s and o.user_id = u.id and n.id = o.name_id order by n.text_name, o.when desc"
    # @data = Location.connection.select_all(query % params[:id])
    @past_location = PastLocation.find(:all, :conditions => "location_id = %s and version = %s" % [@location.id, @location.version - 1]).first

    @map = make_map([@location])
    @header = "#{GMap.header}\n#{@map.to_html}"
  end
  
  # If separator is in where, then look for Locations that match up to but not including the separator.
  # If such locations are found, then return those followed by all the rest of the locations.
  # If no such locations are found, then return nil.
  def sorted_locs(where, separator=nil)
    result = nil
    substring = where
    if separator
      pos = where.index(separator)
      if pos
        substring = where[0..(pos-separator.length)]
      else
        substring = nil
      end
    end
    if substring
      substring_pat = substring + '%'
      matches = Location.find(:all, :conditions => ["display_name like ?", substring_pat], :order => "display_name")
      if matches.length > 0
        others = Location.find(:all, :conditions => ["display_name not like ?", substring_pat], :order => "display_name")
        result = [matches, others]
      end
    end
    result
  end
  
  def list_merge_options
    store_location
    @where = params[:where]
    
    # Look for matches up to the first comma and put them first.
    # If none found, look for matches up to the first space and put them first.
    # If still none found, then just give the whole set ordered by display_name
    @matches, @others = (sorted_locs(@where) || sorted_locs(@where, ',') ||
      sorted_locs(@where, ' ') || [nil, Location.find(:all, :order => "display_name")])
  end
  
  # Adds the observations assoicated with obs.where set to params[:where] into the given location
  def add_to_location
    id = params[:location]
    update_observations_by_where(Location.find(id), params[:where])
    redirect_to(:action => 'list_place_names')
  end
  
  def edit_location
    store_location
    @location = Location.find(params[:id])
  end
  
  def merge_locations(location, dest)
    id = location.id
    if check_permission(0)
      for obs in location.observations
        obs.location = dest
        obs.save
      end
      for past_loc in location.past_locations
        past_loc.destroy
      end
      location.destroy
      id = dest.id
    else
      flash[:notice] = "Because it can be destructive, only the admin can merge existing locations.
        An email requesting the proposed merge has been sent to the admins."
      content = "I attempted to merge the locations, #{location.display_name} and #{dest.display_name}."
      AccountMailer.deliver_webmaster_question(session['user']['email'], content)
    end
    redirect_to(:action => 'show_location', :id => id)
  end
  
  def update_location
    @location = Location.find(params[:id])
    if verify_user() && @location
      user = session['user']
      matching_name = Location.find_by_display_name(params[:location][:display_name])
      if matching_name && (matching_name != @location)
        merge_locations(@location, matching_name)
      else
        @location.attributes = params[:location]
        past_loc = PastLocation.check_for_past_location(@location, user)
        if past_loc
          if @location.save
            past_loc.save # If it fails, then it's too late to do anything.
            flash[:notice] = 'Location was successfully updated.'
            redirect_to(:action => 'show_location', :id => @location)
          else
            flash[:notice] = "Unable to save location #{@location.display_name}."
            render(:action => 'edit_location')
          end
        else
          flash[:notice] = 'No update needed.'
          redirect_to(:action => 'show_location', :id => @location)
        end
      end
    else
      flash[:notice] = 'Need to login to update a location.'
      redirect_to(:action => 'show_location', :id => @location)
    end
  end
end
