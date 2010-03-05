#
#  Views: ("*" - login required, "R" - root required))
#     index_location
#     list_locations
#     locations_by_user
#     locations_by_editor
#     location_search
#     map_locations
#     index_location_description
#     list_location_descriptions
#     location_descriptions_by_author
#     location_descriptions_by_editor
#     show_location
#     show_past_location
#     show_location_description
#     show_past_location_description
#     prev_location
#     next_location
#     prev_location_description
#     next_location_description
#   * create_location
#   * edit_location
#   * create_location_description
#   * edit_location_description
#   * destroy_location_description
#   * list_merge_options
#   * add_to_location
#
#  Helpers:
#     split_out_matches(list, substring)
#     merge_locations(location, dest)
#     update_observations_by_where(location, where)
#
################################################################################

class LocationController < ApplicationController
  before_filter :login_required, :except => [
    :index_location,
    :index_location_description,
    :list_location_descriptions,
    :list_locations,
    :location_descriptions_by_author,
    :location_descriptions_by_editor,
    :location_search,
    :locations_by_editor,
    :locations_by_user,
    :map_locations,
    :next_location,
    :prev_location,
    :next_location_description,
    :prev_location_description,
    :show_location,
    :show_location_description,
    :show_past_location,
    :show_past_location_description,
  ]

  before_filter :disable_link_prefetching, :except => [
    :create_location,
    :create_location_description,
    :edit_location,
    :edit_location_description,
    :show_location,
    :show_location_description,
    :show_past_location,
    :show_past_location_description,
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

  # Display list of locations that a given user is author on.
  def locations_by_user
    user = User.find(params[:id])
    @error = :runtime_locations_by_user_error.t(:user => user.legal_name)
    query = create_query(:Location, :by_user, :user => user)
    show_selected_locations(query)
  end

  # Display list of locations that a given user is editor on.
  def locations_by_editor
    user = User.find(params[:id])
    @error = :runtime_locations_by_editor_error.t(:user => user.legal_name)
    query = create_query(:Location, :by_editor, :user => user)
    show_selected_locations(query)
  end

  # Displays a list of locations matching a given string.
  def location_search
    query = create_query(:Location, :pattern_search, :pattern => params[:pattern].to_s)
    show_selected_locations(query)
  end

  # Show selected search results as a list with 'list_locations' template.
  def show_selected_locations(query, args={})
    store_location
    clear_query_in_session
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
      @links << [:show_objects.t(:type => :observation), {
                  :controller => 'observer',
                  :action => 'index_observation',
                  :params => query_params(query),
                }]
    end

    # Add "show descriptions" link if this query can be coerced into an
    # observation query.
    if query.is_coercable?(:LocationDescription)
      @links << [:show_objects.t(:type => :description), {
                  :action => 'index_location_description',
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
       (!@undef_pages || @undef_pages.num_total == 0) and
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

  ################################################################################
  #
  #  :section: Description Searches and Indexes
  #
  ################################################################################

  # Displays a list of selected locations, based on current Query.
  def index_location_description
    query = find_or_create_query(:LocationDescription, :all,
                                 :by => params[:by] || :name)
    query.params[:by] = params[:by] if params[:by]
    show_selected_location_descriptions(query, :id => params[:id])
  end

  # Displays a list of all location_descriptions.
  def list_location_descriptions
    query = create_query(:LocationDescription, :all, :by => :name)
    show_selected_location_descriptions(query)
  end

  # Display list of location_descriptions that a given user is author on.
  def location_descriptions_by_author
    user = User.find(params[:id])
    @error = :runtime_location_descriptions_by_author_error.
               t(:user => user.legal_name)
    query = create_query(:LocationDescription, :by_author, :user => user)
    show_selected_location_descriptions(query)
  end

  # Display list of location_descriptions that a given user is editor on.
  def location_descriptions_by_editor
    user = User.find(params[:id])
    @error = :runtime_location_descriptions_by_editor_error.
               t(:user => user.legal_name)
    query = create_query(:LocationDescription, :by_editor, :user => user)
    show_selected_location_descriptions(query)
  end

  # Show selected search results as a list with 'list_locations' template.
  def show_selected_location_descriptions(query, args={})
    store_query_in_session(query)
    @links ||= []
    args = { :action => 'list_location_descriptions',
             :num_per_page => 50 }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ['name', :name.t],
    ]

    # Add "show locations" link if this query can be coerced into an
    # observation query.
    if query.is_coercable?(:Location)
      @links << [:show_objects.t(:type => :location), {
                  :action => 'index_location',
                  :params => query_params(query),
                }]
    end

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show Location
  #
  ##############################################################################

  # Show a Location and one of its LocationDescription's, including a map.
  def show_location
    store_location
    pass_query_params
    clear_query_in_session

    # Load Location and LocationDescription along with a bunch of associated
    # objects.
    loc_id = params[:id]
    desc_id = params[:desc]
    @location = Location.find(loc_id, :include => [:user, :descriptions])
    desc_id = @location.description_id if desc_id.to_s == ''
    if desc_id.to_s != ''
      @description = LocationDescription.find(desc_id, :include =>
                                        [:authors, :editors, :license, :user])
      @description = nil if !@description.is_reader?(@user)
    else
      @description = nil
    end

    update_view_stats(@location)
    update_view_stats(@description) if @description

    # Get a list of projects the user can create drafts for.
    @projects = @user && @user.projects_member.select do |project|
      !@location.descriptions.any? {|d| d.belongs_to_project?(project)}
    end
  end

  # Show just a LocationDescription.
  def show_location_description
    store_location
    pass_query_params
    @description = LocationDescription.find(params[:id], :include =>
      [ :authors, :editors, :license, :user, {:location => :descriptions} ])

    # Public or user has permission.
    if @description.is_reader?(@user)
      @location = @description.location
      update_view_stats(@description)

      # Get a list of projects the user can create drafts for.
      @projects = @user && @user.projects_member.select do |project|
        !@location.descriptions.any? {|d| d.belongs_to_project?(project)}
      end

    # User doesn't have permission to see this description.
    else
      if @description.source_type == :project
        flash_error(:runtime_show_draft_denied.t)
        if project = Project.find_by_title(@description.source_name)
          redirect_to(:controller => 'project', :action => 'show_project',
                      :id => project.id)
        else
          redirect_to(:action => 'show_location', :id => @description.location_id)
        end
      else
        flash_error(:runtime_show_description_denied.t)
        redirect_to(:action => 'show_location', :id => @description.location_id)
      end
    end
  end

  # Show past version of Location.  Accessible only from show_location page.
  def show_past_location
    store_location
    pass_query_params
    @location = Location.find(params[:id])
    @location.revert_to(params[:version].to_i)
  end

  # Show past version of LocationDescription.  Accessible only from
  # show_location_description page.
  def show_past_location_description
    store_location
    pass_query_params
    @description = LocationDescription.find(params[:id])
    @description.revert_to(params[:version].to_i)
  end

  # Go to next location: redirects to show_location.
  def next_location
    redirect_to_next_object(:next, Location, params[:id])
  end

  # Go to previous location: redirects to show_location.
  def prev_location
    redirect_to_next_object(:prev, Location, params[:id])
  end

  # Go to next location: redirects to show_location.
  def next_location_description
    redirect_to_next_object(:next, LocationDescription, params[:id])
  end

  # Go to previous location: redirects to show_location.
  def prev_location_description
    redirect_to_next_object(:prev, LocatioDescriptionn, params[:id])
  end

  ##############################################################################
  #
  #  :section: Create/Edit Location
  #
  ##############################################################################

  def create_location
    store_location
    pass_query_params

    # (Used when linked from "define this location".)
    @where = params[:where]

    # (Used when linked from user profile: sets primary location after done.)
    @set_user = (params[:set_user] == "1")

    # Reder a blank form.
    if request.method != :post
      @location = Location.new

    else
      # Set to true below if created successfully, or if a matching location
      # already exists.  In either case, we're done with this form.
      done = false

      # Look to see if the display name is already use.  If it is then just use
      # that location and ignore the other values.  Probably should be smarter
      # with warnings and merges and such...
      name = params[:location][:display_name].strip_squeeze rescue ''
      @location = Location.find_by_display_name(name)

      # Location already exists.
      if @location
        flash_warning(:runtime_location_already_exists.t(:name => name))
        done = true

      # Need to create location.
      elsif (@location = Location.new(params[:location])) and
            @location.save
        Transaction.post_location(
          :id      => @location,
          :created => @location.created,
          :name    => @location.display_name,
          :north   => @location.north,
          :south   => @location.south,
          :east    => @location.east,
          :west    => @location.west,
          :low     => @location.low,
          :high    => @location.high
        )
        flash_notice(:runtime_location_success.t(:id => @location.id))
        done = true

      # Failed to create location
      else
        flash_object_errors @location
      end

      # If done, update any observations at @where string originally passed in,
      # and set user's primary location if called from profile.
      if done
        if @where.to_s != ''
          update_observations_by_where(@location, @where)
        end
        if @set_user
          @user.location = @location
          @user.save
          Transaction.put_user(
            :id           => @user,
            :set_location => @location
          )
        end
        redirect_to(:action => 'show_location', :id => @location.id)
      end
    end
  end

  def edit_location
    store_location
    pass_query_params
    @location = Location.find(params[:id])
    done = false
    if request.method == :post

      # First check if user changed the name to one that already exists.
      name = params[:location][:display_name].strip_squeeze rescue ''
      merge = Location.find_by_display_name(name)

      # Merge with another location.
      if merge && merge != @location

        # Swap order if only one is mergable.
        if !@location.mergable? && merge.mergable?
          @location, merge = merge, @location
        end

        # Admins can actually merge them, then redirect to other location.
        if is_in_admin_mode? || @location.mergable?
          merge.merge(@location)
          merge.save if merge.changed?
          @location = merge
          done = true

        # Non-admins just send email-request to admins.
        else
          flash_warning(:runtime_merge_locations_warning.t)
          content = :email_location_merge.t(:user => @user.login,
                  :this => @location.display_name, :that => merge.display_name)
          AccountMailer.deliver_webmaster_question(@user.email, content)
        end

      # Otherwise it is safe to change the name.
      else
        @location.display_name = name
      end

      # Just update this location.
      if !done
        for key, val in params[:location]
          if key != 'display_name'
            @location.send("#{key}=", val)
          end
        end

        args = {}
        args[:set_name]  = @location.display_name if @location.display_name_changed?
        args[:set_north] = @location.north        if @location.north_changed?
        args[:set_south] = @location.south        if @location.south_changed?
        args[:set_west]  = @location.west         if @location.west_changed?
        args[:set_east]  = @location.east         if @location.east_changed?
        args[:set_high]  = @location.high         if @location.high_changed?
        args[:set_low]   = @location.low          if @location.low_changed?

        # No changes made.
        if !@location.changed?
          flash_warning(:runtime_edit_location_no_change.t)
          redirect_to(:action => 'show_location', :id => @location.id)

        # There were error(s).
        elsif !@location.save
          flash_object_errors @location

        # Updated successfully.
        else
          if !args.empty?
            args[:id] = @location
            Transaction.put_location(args)
          end
          flash_notice(:runtime_edit_location_success.t(:id => @location.id))
          done = true
        end
      end
    end

    if done
      redirect_to(:action => 'show_location', :id => @location.id)
    end
  end

  def create_location_description
    store_location
    pass_query_params
    @location = Location.find(params[:id])
    @licenses = License.current_names_and_ids

    # Reder a blank form.
    if request.method == :get
      @description = LocationDescription.new
      @description.location = @location
      @description.license = @user.license

      # Initialize source-specific stuff.
      case params[:source]
      when 'project'
        @description.source_type  = :project
        @description.source_name  = Project.find(params[:project])
        @description.public_write = false
        @description.public       = false
      else
        @description.source_type  = :user
        @description.source_name  = @user.legal_name
        @description.public_write = false
        @description.public       = true
      end

    # Create new description.
    else
      @description = LocationDescription.new
      @description.location = @location
      @description.attributes = params[:description]

      if @description.save
        initialize_description_permissions(@description)

        Transaction.post_location_description(
          @description.all_notes.merge(
            :id            => @description,
            :created       => @description.created,
            :source_type   => @description.source_type,
            :source_name   => @description.source_name,
            :locale        => @description.locale,
            :license       => @description.license,
            :admin_groups  => @description.admin_groups,
            :writer_groups => @description.writer_groups,
            :reader_groups => @description.reader_groups
          )
        )

        flash_notice(:runtime_location_description_success.t(
                     :id => @description.id))
        redirect_to(:action => 'show_location_description',
                    :id => @description.id)

      else
        flash_object_errors @description
      end
    end
  end

  def edit_location_description
    store_location
    pass_query_params
    @description = LocationDescription.find(params[:id])
    @licenses = License.current_names_and_ids

    if !@description.is_writer?(@user)
      flash_error(:runtime_edit_description_denied.t)
      if @description.is_reader?(@user)
        redirect_to(:action => 'show_location_description', :id => @description.id)
      else
        redirect_to(:action => 'show_location', :id => @description.location_id)
      end

    elsif request.method == :post
      @description.attributes = params[:description]

      args = {}
      args["set_source_type"] = @description.source_type if @description.source_type_changed?
      args["set_source_name"] = @description.source_name if @description.source_name_changed?
      args["set_locale"]      = @description.locale      if @description.locale_changed?
      args["set_license"]     = @description.license     if @description.license_id_changed?
      for field in LocationDescription.all_note_fields
        if @description.send("#{field}_changed?")
          args["set_#{field}".to_sym] = @description.send(field)
        end
      end

      # Modify permissions based on changes to the two "public" checkboxes.
      modify_description_permissions(@description, args)

      # No changes made.
      if args.empty?
        flash_warning(:runtime_edit_location_description_no_change.t)
        redirect_to(:action => 'show_location_description',
                    :id => @description.id)

      # There were error(s).
      elsif !@description.save
        flash_object_errors(@description)

      # Updated successfully.
      else
        if !args.empty?
          args[:id] = @description
          Transaction.put_location_description(args)
        end
        flash_notice(:runtime_edit_location_description_success.t(
                     :id => @description.id))
        redirect_to(:action => 'show_location_description',
                    :id => @description.id)
      end
    end
  end

  def destroy_location_description
    pass_query_params
    @description = LocationDescription.find(params[:id])
    if @description.is_admin?(@user)
      flash_notice(:runtime_destroy_description_success.t)
      @description.destroy
      redirect_to(:action => 'show_location', :id => @description.location_id,
                  :params => query_params)
    else
      flash_error(:runtime_destroy_description_not_admin.t)
      if @description.is_reader?(@user)
        redirect_to(:action => 'show_location_description', :id => @description.id,
                    :params => query_params)
      else
        redirect_to(:action => 'show_location', :id => @description.location_id,
                    :params => query_params)
      end
    end
  end

  ##############################################################################
  #
  #  :section: Merging Locations
  #
  ##############################################################################

  # Show a list of defined locations that match a given +where+ string, in
  # order of closeness of match.
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

  # Adds the Observation's associated with <tt>obs.where == params[:where]</tt>
  # into the given Location.  Linked from +list_merge_options+, I think.
  def add_to_location
    location = Location.find(params[:location])
    where = params[:where].strip_squeeze rescue ''
    if (where != '') and
       update_observations_by_where(location, where)
      flash_notice(:runtime_location_merge_success.t(:this => where,
                   :that => location.display_name))
    end
    redirect_to(:action => 'list_locations')
  end

  # Move all the Observation's with a given +where+ into a given Location.
  def update_observations_by_where(location, where)
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
          flash_error :runtime_location_merge_failed.t(:name => o.unique_format_name)
          success = false
        end
      end
    end
    return success
  end
end

