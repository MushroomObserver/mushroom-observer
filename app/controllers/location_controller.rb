# Copyright (c) 2008 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

class LocationController < ApplicationController
  before_filter :login_required, :except => [
    :list_place_names,
    :map_locations,
    :show_location,
    :show_past_location,
    :where_search
  ]

  # Either displays matrix of observations at a location alphabetically
  # if a location is given, else lists all location names.
  # Redirects to: location_search (observer), or list_place_names (here)
  # Inputs: params[:id] (location id)
  def where_search
    where = params[:where]
    if where
      session[:where] = where
    end
    where = session[:where]
    if where
      redirect_to :controller => "observer", :action => "location_search", :pattern => where
    else
      redirect_to :action => "list_place_names"
    end
  end

  def list_place_names
    known_condition = ''
    undef_condition = ''
    @pattern = params[:pattern]
    if @pattern
      sql_pattern = clean_sql_pattern(@pattern)
      known_condition = "and l.display_name like '%#{sql_pattern}%'"
      undef_condition = "and o.where like '%#{sql_pattern}%'"
      logger.info("  ***  list_place_names: #{known_condition}, #{undef_condition}")
    end
    known_query = "select o.location_id, l.display_name, count(1) as cnt
      from observations o, locations l where o.location_id = l.id #{known_condition}
      group by o.location_id, l.display_name order by l.display_name"
    @known_data = Observation.connection.select_all(known_query)
    undef_query = "select o.where, count(1) as cnt
      from observations o where o.location_id is NULL #{undef_condition}
      group by o.where order by cnt desc"
    @undef_data = Observation.connection.select_all(undef_query)
  end

  def map_locations
    @pattern = params[:pattern]
    locations = []
    if @pattern && (@pattern != '')
      locations = Location.find(:all, :conditions => "display_name like '%#{clean_sql_pattern(@pattern)}%'")
    else
      locations = Location.find(:all)
    end
    @map = nil
    @header = nil
    if locations.length > 0
      @map = make_map(locations)
      @header = "#{GMap.header}\n#{finish_map(@map)}"
    end
  end

  def create_location
    store_location
    @user = session['user']
    @where = params[:where]
    if verify_user()
      if request.method == :get
        @location = Location.new
      else
        # Look to see if the display name is already use.  If it is then just use that
        # location and ignore the other values.  Probably should be smarter with warnings
        # and merges and such...
        @location = Location.find_by_display_name(params[:location][:display_name])
        if @location # location already exists
          flash_warning "This location already exists."
          update_observations_by_where(@location, @where)
          redirect_to(:action => 'show_location', :id => @location)
        else         # need to create location
          @location = Location.new(params[:location])
          @location.created = Time.now
          @location.modified = @location.created
          @location.user = @user
          @location.version = 0
          if @location.save()
            flash_notice "Location was successfully added."
            update_observations_by_where(@location, @where)
            redirect_to(:action => 'show_location', :id => @location)
          else
            flash_object_errors @location
          end
        end
      end
    end
  end

  def update_observations_by_where(location, where)
    return false if !where
    success = true
    observations = Observation.find_all_by_where(where)
    for o in observations
      unless o.location_id
        o.location = location
        o.where = nil
        if !o.save
          flash_error "Failed to merge observation #{o.unique_text_name}."
          success = false
        end
      end
    end
    return success
  end

  def show_past_location
    store_location
    @past_location = PastLocation.smart_find_id(params[:id])
    @other_versions = PastLocation.find(:all, :conditions => "location_id = %s" % @past_location.location_id, :order => "version desc")
    @map = make_map([@past_location])
    @header = "#{GMap.header}\n#{finish_map(@map)}"
  end

  def show_location
    store_location
    id = params[:id]
    @location = Location.smart_find_id(id)
    # query = "select o.id, o.when, o.modified, o.when, o.thumb_image_id, o.where, o.location_id," +
    #         " u.name, u.login, n.observation_name from observations o, users u, names n" +
    #         " where o.location_id = %s and o.user_id = u.id and n.id = o.name_id order by n.text_name, o.when desc"
    # @data = Location.connection.select_all(query % params[:id])
    @past_location = PastLocation.find(:all, :conditions => "location_id = %s and version = %s" % [@location.id, @location.version - 1]).first
    
    @map = make_map([@location])
    @header = "#{GMap.header}\n#{finish_map(@map)}"
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
    location = Location.smart_find_id(params[:location])
    where = params[:where]
    flash_notice "Successfully merged #{where} with #{location.display_name}." \
      if update_observations_by_where(location, where)
    redirect_to(:action => 'list_place_names')
  end

  def edit_location
    store_location
    @location = Location.smart_find_id(params[:id])
    if verify_user()
      @user = session['user']
      if request.method == :post
        matching_name = Location.find_by_display_name(params[:location][:display_name])
        if matching_name && (matching_name != @location)
          merge_locations(@location, matching_name)
        else
          @location.attributes = params[:location]
          past_loc = PastLocation.check_for_past_location(@location, @user)
          if past_loc
            if @location.save
              flash_notice "Location was successfully updated."
              flash_warning "Failed to save log of changes, though." \
                if !past_loc.save
              redirect_to(:action => 'show_location', :id => @location)
            else
              flash_object_errors @location
            end
          else
            flash_warning "No update needed."
            redirect_to(:action => 'show_location', :id => @location)
          end
        end
      end
    end
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
      flash_warning "Because it can be destructive, only the admin can merge existing locations.
        An email requesting the proposed merge has been sent to the admins."
      content = "I attempted to merge the locations, #{location.display_name} and #{dest.display_name}."
      AccountMailer.deliver_webmaster_question(session['user']['email'], content)
    end
    redirect_to(:action => 'show_location', :id => id)
  end
end
