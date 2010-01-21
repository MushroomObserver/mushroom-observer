#
#  Views: ("*" - login required, "R" - root required))
#     where_search
#     list_place_names
#     map_locations
#   * create_location
#   * update_observations_by_where(location, where)
#     show_past_location
#     show_location
#   * list_merge_options
#   * add_to_location
#   * edit_location
#   * review_authors            Let authors/reviewers add/remove authors.
#   * author_request            Let non-authors request authorship credit.
#   * send_author_request       (post method of author_request)
#   R merge_locations(location, dest)
#
#  AJAX:
#     auto_complete_location
#
#  Helpers:
#     sorted_locs(where, separator=nil)
#
################################################################################

class LocationController < ApplicationController
  before_filter :login_required, :except => [
    :list_place_names,
    :map_locations,
    :show_location,
    :show_past_location,
    :where_search,
    :auto_complete_location
  ]

  # Process AJAX request for autocompletion of location fields.  It reads the
  # first letter of the field, and returns all the locations (or "wheres")
  # with words beginning with that letter.
  # Inputs: params[:letter]
  # Outputs: renders sorted list of names, one per line, in plain text
  def auto_complete_location
    letter = params[:letter] || ''
    if letter.length > 0
      @items = Location.connection.select_values %(
        SELECT DISTINCT IF(observations.location_id > 0, locations.display_name, observations.where) AS x
        FROM observations
        LEFT OUTER JOIN locations ON locations.id = observations.location_id
        WHERE (
          LOWER(observations.where) LIKE '#{letter}%' OR
          LOWER(observations.where) LIKE '% #{letter}%' OR
          LOWER(locations.search_name) LIKE '#{letter}%' OR
          LOWER(locations.search_name) LIKE '% #{letter}%'
        )
        ORDER BY x ASC
      )
    else
      letter = ' '
      @items = []
    end
    render(:inline => letter + '<%= @items.map {|n| h(n) + "\n"}.join("") %>')
  end

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
      redirect_to(:controller => "observer", :action => "location_search", :where => where)
    else
      redirect_to(:action => "list_place_names")
    end
  end

  def list_place_names
    known_condition = ''
    undef_condition = ''
    @pattern = params[:pattern] || ''
    id = @pattern.to_i
    loc = nil
    if @pattern == id.to_s
      begin
        loc = Location.find(id)
      rescue ActiveRecord::RecordNotFound
      end
    end
    if loc
      redirect_to(:controller => 'location', :action => 'show_location', :id => loc)
    else
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
  end

  def map_locations
    @pattern = params[:pattern]
    locations = []
    if @pattern && (@pattern != '')
      locations = Location.find(:all, :conditions => "display_name like '%#{clean_sql_pattern(@pattern)}%'")
    else
      @title = :map_locations_global_map.t
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
    @where = params[:where]
    @set_user = (params[:set_user] == "1")
    @licenses = License.current_names_and_ids()
    if request.method == :get
      @location = Location.new
    else
      # Look to see if the display name is already use.  If it is then just use that
      # location and ignore the other values.  Probably should be smarter with warnings
      # and merges and such...
      @location = Location.find_by_display_name(params[:location][:display_name])
      if @location # location already exists
        flash_warning :create_location_already_exists.t
        update_observations_by_where(@location, @where)
        if @set_user
          @user.location = @location
          @user.save
        end
        redirect_to(:action => 'show_location', :id => @location.id)
      else         # need to create location
        @location = Location.new(params[:location])
        @location.created = Time.now
        @location.modified = @location.created
        @location.user = @user
        @location.version = 0
        if @location.save
          Transaction.post_location(
            :id      => @location,
            :created => @location.created,
            :name    => @location.display_name,
            :notes   => @location.notes,
            :north   => @location.north,
            :south   => @location.south,
            :east    => @location.east,
            :west    => @location.west,
            :low     => @location.low,
            :high    => @location.high,
            :license => @location.license || 0
          )
          @location.add_editor(@user)
          flash_notice :create_location_success.t
          update_observations_by_where(@location, @where)
          if @set_user
            @user.location = @location
            @user.save
            Transaction.put_user(
              :id           => @user,
              :set_location => @location
            )
          end
          redirect_to(:action => 'show_location', :id => @location.id)
        else
          flash_object_errors @location
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
        if o.save
          Transaction.put_observation(
            :id           => o,
            :set_location => location
          )
        else
          flash_error :create_location_merge_failed.t(:name => o.unique_format_name)
          success = false
        end
      end
    end
    return success
  end

  def show_past_location
    store_location
    @location = Location.find(params[:id])
    @past_location = Location.find(params[:id].to_i) # clone or dclone?
    @past_location.revert_to(params[:version].to_i)
    @other_versions = @location.versions.reverse
    @map = make_map([@past_location])
    @header = "#{GMap.header}\n#{finish_map(@map)}"
  end

  def show_location
    store_location
    id = params[:id]
    @location = Location.find(id)
    # query = "select o.id, o.when, o.modified, o.when, o.thumb_image_id, o.where, o.location_id," +
    #         " u.name, u.login, n.observation_name from observations o, users u, names n" +
    #         " where o.location_id = %s and o.user_id = u.id and n.id = o.name_id order by n.text_name, o.when desc"
    # @data = Location.connection.select_all(query % params[:id])
    @past_location = @location.versions.latest
    @past_location = @past_location.previous if @past_location
    @map = make_map([@location])
    @header = "#{GMap.header}\n#{finish_map(@map)}"
    @interest = nil
    @interest = Interest.find_by_user_id_and_object_type_and_object_id(@user.id, 'Location', @location.id) if @user
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
    location = Location.find(params[:location])
    where = params[:where]
    if update_observations_by_where(location, where)
      flash_notice :location_merge_success.t(:this => where, :that => location.display_name)
    end
    redirect_to(:action => 'list_place_names')
  end

  def edit_location
    store_location
    @location = Location.find(params[:id])
    @licenses = License.current_names_and_ids()
    if request.method == :post
      matching_name = Location.find_by_display_name(params[:location][:display_name])
      if matching_name && (matching_name != @location)
        merge_locations(@location, matching_name)
      else
        @location.attributes = params[:location]
        args = {}
        args[:set_name]    = @location.display_name if @location.display_name_changed?
        args[:set_north]   = @location.north        if @location.north_changed?
        args[:set_south]   = @location.south        if @location.south_changed?
        args[:set_west]    = @location.west         if @location.west_changed?
        args[:set_east]    = @location.east         if @location.east_changed?
        args[:set_high]    = @location.high         if @location.high_changed?
        args[:set_low]     = @location.low          if @location.low_changed?
        args[:set_notes]   = @location.notes        if @location.notes_changed?
        args[:set_license] = @location.license      if @location.license_id_changed?
        if !@location.changed?
          flash_warning :edit_location_no_change.t
          redirect_to(:action => 'show_location', :id => @location.id)
        elsif @location.save
          if !args.empty?
            args[:id] = @location
            Transaction.put_location(args)
          end
          flash_notice :edit_location_success.t
          redirect_to(:action => 'show_location', :id => @location.id)
        elsif @location.errors.length > 0
          flash_object_errors @location
        end
      end
    end
  end

  def merge_locations(location, dest)
    id = location.id
    if is_in_admin_mode?
      for obs in location.observations
        obs.location = dest
        obs.save
      end
      Transaction.put_observation(
        :location     => location,
        :set_location => dest
      )
      for past_loc in location.versions
        past_loc.destroy
      end
      location.destroy
      Transaction.delete_location(:id => location)
      id = dest.id
    else
      flash_warning :merge_locations_warning.t
      content = "User attempted to merge the locations, #{location.display_name} and #{dest.display_name}."
      AccountMailer.deliver_webmaster_question(@user.email, content)
    end
    redirect_to(:action => 'show_location', :id => id)
  end

  # Form to allow authors to add/remove other users as author.
  # Linked from: show_location, author_request email
  # Inputs:
  #   params[:id]
  #   params[:add]
  #   params[:remove]
  # Success:
  #   Redraws itself.
  # Failure:
  #   Renders show_location.
  #   Outputs: @location, @authors, @users
  def review_authors
    @location = Location.find(params[:id])
    @authors = @location.authors
    if @authors.member?(@user) or @user.in_group('reviewers')
      @users = User.find(:all, :order => "login, name")

      # Add author if :add parameter used.
      new_author = params[:add] ? User.find(params[:add]) : nil
      if new_author and not @location.authors.member?(new_author)
        @location.add_author(new_author)
        Transaction.put_location(
          :id         => @location,
          :add_author => new_author
        )
        flash_notice("Added #{new_author.legal_name}")
        # Should send email as well
      end

      # Remove author if :remove parameter used.
      old_author = params[:remove] ? User.find(params[:remove]) : nil
      if old_author
        @location.remove_author(old_author)
        Transaction.put_location(
          :id         => @location,
          :del_author => old_author
        )
        flash_notice("Removed #{old_author.legal_name}")
        # Should send email as well
      end

    else
      flash_error(:review_authors_denied.t)
      redirect_to(:action => 'show_location', :id => @location.id)
    end
  end

  # Form to compose email for the authors/reviewers
  # Linked from: show_location
  # Inputs:
  #   params[:id]
  # Outputs: @location
  def author_request
    @location = Location.find(params[:id])
  end

  # Sends email to the authors/reviewers
  # Linked from: author_request
  # Inputs:
  #   params[:id]
  #   params[:email][:subject]
  #   params[:email][:content]
  # Success:
  #   Redirects to show_location.
  #
  # TODO: Use queued_email mechanism
  def send_author_request
    sender = @user
    location = Location.find(params[:id])
    subject = params[:email][:subject]
    content = params[:email][:content]
    for receiver in location.authors + UserGroup.find_by_name('reviewers').users
      AccountMailer.deliver_author_request(sender, receiver, location, subject, content)
    end
    flash_notice(:request_success.t)
    redirect_to(:action => 'show_location', :id => location.id)
  end
end
