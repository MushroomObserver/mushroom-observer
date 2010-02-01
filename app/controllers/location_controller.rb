#
#  Views: ("*" - login required, "R" - root required))
#     location_search
#     list_locations
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
    :auto_complete_location,
    :list_locations,
    :location_search,
    :map_locations,
    :show_location,
    :show_past_location,
  ]

  before_filter :disable_link_prefetching, :except => [
    :author_request,
    :create_location,
    :edit_location,
    :show_location,
    :show_past_location,
  ]

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  # Displays a list of all locations.
  def list_locations
    query = find_or_create_query(:Location, :all, :by => :name)
    @title = :location_index_title.t
    show_selected_locations(query)
  end

  # Displays a list of locations matching a given string.
  def location_search
    @pattern = params[:pattern].to_s
    query = create_query(:Location, :pattern, :pattern => @pattern)
    @title = :location_index_title.t
    show_selected_locations(query)
  end

  # Show selected search results as a list with 'list_locations' template.
  def show_selected_locations(query)
    store_location
    store_query
    set_query_params(query)

    @known_pages = paginate_numbers(:page, 50)
    @known_data  = query.paginate(@known_pages)

    # Try to turn this into a query on observations.where instead.
    query.include << :observations
    sql = query.query(
      :select => 'DISTINCT observations.`where`, COUNT(1) AS cnt',
      :order  => 'cnt DESC'
    )
    sql.gsub!(/locations.(display|search)_name/, 'observations.`where`')
    sql += " GROUP BY observations.`where`"

    @undef_pages = paginate_numbers(:page2, 50)
    @undef_data = Location.connection.select_all(sql) rescue []
    @undef_pages.num_total = @undef_data.length
    @undef_data = @undef_data[@undef_pages.from..@undef_pages.to]

    # If only one result (before pagination), redirect to show_location.
    if (@known_pages.num_total == 1) and
       (@undef_pages.num_total == 0) and
       (object = @known_data.first)
      redirect_to(:action => 'show_location', :id => object.id)

    # Otherwise paginate results.
    else
      render(:action => 'list_locations')
    end
  end

  # Map results of a search or index.
  def map_locations
    @pattern = params[:pattern].to_s
    if @pattern == ''
      @title = :map_locations_global_map.t
      query = find_or_create_query(:Location, :all, :by => :name)
    else
      @title = :map_locations_title.t(:pattern => @pattern)
      query = find_or_create_query(:Location, :pattern, :pattern => @pattern)
    end
    @locations = query.results
  end

  ##############################################################################
  #
  #  :section: Show Location
  #
  ##############################################################################

  def show_location
    store_location
    pass_query_params
    @location = Location.find(params[:id])
    @past_location = @location.versions.latest
    @past_location = @past_location.previous if @past_location
    @interest = nil
    @interest = Interest.find_by_user_id_and_object_type_and_object_id(@user.id, 'Location', @location.id) if @user
  end

  def show_past_location
    store_location
    pass_query_params
    @location = Location.find(params[:id])
    @past_location = Location.find(params[:id].to_i)
    @past_location.revert_to(params[:version].to_i)
    @other_versions = @location.versions.reverse
  end

  # Go to next location: redirects to show_location.
  def next_location
    location = Location.find(params[:id])
    redirect_to_next_object(:next, location)
  end

  # Go to previous location: redirects to show_location.
  def prev_location
    location = Location.find(params[:id])
    redirect_to_next_object(:prev, location)
  end

  ##############################################################################
  #
  #  Create/Edit Location
  #
  ##############################################################################

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

  ##############################################################################
  #
  #  :section: Merging Locations
  #
  ##############################################################################

  def list_merge_options
    store_location
    @where = params[:where]

    # Look for matches up to the first comma and put them first.
    # If none found, look for matches up to the first space and put them first.
    # If still none found, then just give the whole set ordered by display_name
    @matches, @others = (sorted_locs(@where) || sorted_locs(@where, ',') ||
      sorted_locs(@where, ' ') || [nil, Location.find(:all, :order => "display_name")])
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

  # Adds the observations assoicated with obs.where set to params[:where] into the given location
  def add_to_location
    location = Location.find(params[:location])
    where = params[:where]
    if update_observations_by_where(location, where)
      flash_notice :location_merge_success.t(:this => where, :that => location.display_name)
    end
    redirect_to(:action => 'list_locations')
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

  ##############################################################################
  #
  #  :section: Reviewing and Authors
  #
  ##############################################################################

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

  # Form accessible from show_location to let users request authorship credit
  # on a Location. TODO: Use queued_email mechanism.
  def author_request
    @location = Location.find(params[:id])
    if request.method == :post
      subject = params[:email][:subject]
      content = params[:email][:content]
      for receiver in location.authors + UserGroup.find_by_name('reviewers').users
        AccountMailer.deliver_author_request(@user, receiver, location, subject, content)
      end
      flash_notice(:request_success.t)
      redirect_to(:action => 'show_location', :id => location.id,
                  :params => query_params)
    end
  end
end
