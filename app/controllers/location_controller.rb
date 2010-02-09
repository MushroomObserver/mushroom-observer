#
#  Views: ("*" - login required, "R" - root required))
#     location_search
#     index_location
#     list_locations
#     map_locations
#   * create_location
#   * update_observations_by_where(location, where)
#     show_past_location
#     show_location
#     prev_location             Show previous location in index.
#     next_location             Show next location in index.
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
    :index_location,
    :list_locations,
    :location_search,
    :map_locations,
    :next_location,
    :prev_location,
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

  # Displays a list of selected locations, based on current Query.
  def index_location
    query = find_or_create_query(:Location, :all, :by => params[:by] || :name)
    query.params[:by] = params[:by] if params[:by]
    show_selected_locations(query, :id => params[:id])
  end

  # Displays a list of all locations.
  def list_locations
    query = create_query(:Location, :all, :by => :name)
    show_selected_locations(query)
  end

  # Displays a list of locations matching a given string.
  def location_search
    query = create_query(:Location, :pattern, :pattern => params[:pattern].to_s)
    show_selected_locations(query)
  end

  # Show selected search results as a list with 'list_locations' template.
  def show_selected_locations(query, args={})
    store_location
    store_query
    set_query_params(query)

    # Supply a default title.
    @title ||= query.title

    # Add some alternate sorting criteria.
    @links = add_sorting_links(query, [
      ['name', :name.t], 
    ])

    # Add "show observations" link if this query can be coerced into an
    # observation query.
    if query.is_coercable?(:Observation)
      @links << [:app_show_objects.t(:types => :observations.t), {
                  :controller => 'observer', 
                  :action => 'index_observation',
                  :params => query_params(query),
                }]
    end

    # Try to turn this into a query on observations.where instead.
    # Yesyesyes, this is a tremendous kludge, but tell me how else to do it?
    # It is known to work on the following :Location query flavors:
    #   :all
    #   :pattern
    #   :with_observations_of_name
    begin
      sql = query.query(
        :select => 'DISTINCT observations.`where`, COUNT(1) AS cnt',
        :where  => 'observations.location_id IS NULL',
        :group  => 'observations.`where`',
        :order  => 'cnt DESC'
      )

      # Remove condition joining observations to locations (if present).
      sql.sub!(' AND (observations.location_id = locations.id)', '')
      # Convert any conditions on 'location name' to 'observation where'.
      sql.gsub!(/locations.(display|search)_name/, 'observations.`where`')
      # Remove any non-critical conditions on 'location notes'.
      sql.gsub!(/ OR locations.notes LIKE '[^']+'/, '')
      # Remove locations from list of tables.
      sql.sub!(/(FROM [^A-Z]*)`locations`,?/, '\\1')
      # Add observations to list of tables (if not already there).
      sql.sub!(/FROM [^A-Z\n]*/) do |x|
        x.index('`observations`') ? x : "#{x.sub(/,$/,',')} `observations`"
      end
# flash_notice("ORIGINAL = " + query.query.gsub("\n",'<br/>'))
# flash_notice("TWEAKED  = " + sql.gsub("\n",'<br/>'))
      # Fail if there is still a condition requiring locations.
      raise if sql.match('locations.')

      @undef_pages = paginate_letters(:letter2, :page2, 50)
      @undef_data = Observation.connection.select_all(sql)
      @undef_pages.used_letters = @under_data.map {|r| r[0][0,1]}.uniq
      if (letter = params[:letter2].to_s.downcase) != ''
        @undef_data = @undef_data.select {|r| r[0][0,1].downcase == letter}
      end
      @undef_pages.num_total = @undef_data.length
      @undef_data = @undef_data[@undef_pages.from..@undef_pages.to]
    rescue
      @undef_pages = nil
      @undef_data = nil
    end

    # Now it's okay to paginate this (query.paginate with letters can cause
    # it to add a condition to the query to select for a letter).
    @known_pages = paginate_letters(:letter, :page, 50)
    if (args[:id].to_s != '') and
       (params[:letter].to_s == '') and
       (params[:page].to_s == '')
      @known_pages.show_index(query.index(args[:id]))
    end
    @known_data = query.paginate(@known_pages,
                                 :letter_field => 'locations.search_name')

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
    query = find_or_create_query(:Location, :all)
    @title = query.flavor == :all ? :map_locations_global_map.t :
                             :map_locations_title.t(:locations => query.title)
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
    @location = Location.find(params[:id], :include => [:user, :authors, :editors])
    @previous_version = Location.connection.select_value %(
      SELECT version FROM past_locations WHERE location_id = #{@location.id}
      ORDER BY version DESC LIMIT 1, 1
    )
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
    redirect_to_next_object(:next, Location, params[:id])
  end

  # Go to previous location: redirects to show_location.
  def prev_location
    redirect_to_next_object(:prev, Location, params[:id])
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
    @where = params[:where].to_s

    # Split list of all locations into "matches" and "non-matches".  Try
    # matches in the following order:
    #   1) all that start with full "where" string
    #   2) all that start with everything in "where" up to the comma
    #   3) all that start with the first word in "where"
    #   4) there just aren't any matches, give up
    all = Location.all(:order => 'display_name')
    @matches, @others = (
      split_out_matches(all, @where) or
      split_out_matches(all, @where.split(',').first) or
      split_out_matches(all, @where.split(' ').first) or
      [nil, all]
    )
  end

  # Split up +list+ into those that start with +substring+ and those that
  # don't.  If none match, then return nil.
  def split_out_matches(list, substring)
    matches = list.select do |loc|
      (loc.display_name.to_s[0,substring.length] == substring) or
      (loc.search_name.to_s[0,substring.length] == substring)
    end
    if matches.empty?
      nil
    else
      [matches, list - matches]
    end
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
        o.location_id = location.id
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
