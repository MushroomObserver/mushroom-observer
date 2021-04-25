# frozen_string_literal: true

require("geocoder")

# Location controller.
class LocationController < ApplicationController
  include DescriptionControllerHelpers

  before_action :login_required, except: [
    :advanced_search,
    :help,
    :index_location,
    :index_location_description,
    :list_by_country,
    :list_countries,
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
    :show_past_location_description
  ]

  before_action :disable_link_prefetching, except: [
    :create_location,
    :create_location_description,
    :edit_location,
    :edit_location_description,
    :show_location,
    :show_location_description,
    :show_past_location,
    :show_past_location_description
  ]

  before_action :require_successful_user, only: [
    :create_location_description
  ]

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  # Displays a list of selected locations, based on current Query.
  def index_location
    query = find_or_create_query(:Location, by: params[:by])
    show_selected_locations(query, id: params[:id].to_s, always_index: true)
  end

  # Displays a list of all countries with counts.
  def list_countries
    @cc = CountryCounter.new
  end

  # Displays a list of all locations whose country matches the id param.
  def list_by_country
    query = create_query(
      :Location, :regexp_search, regexp: "#{params[:country]}$"
    )
    show_selected_locations(query, link_all_sorts: true)
  end

  # Displays a list of all locations.
  def list_locations
    query = create_query(:Location, :all, by: :name)
    show_selected_locations(query, link_all_sorts: true)
  end

  # Display list of locations that a given user is author on.
  def locations_by_user
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:Location, :by_user, user: user)
    show_selected_locations(query, link_all_sorts: true)
  end

  # Display list of locations that a given user is editor on.
  def locations_by_editor
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:Location, :by_editor, user: user)
    show_selected_locations(query)
  end

  # Displays a list of locations matching a given string.
  def location_search
    pattern = params[:pattern].to_s
    loc = Location.safe_find(pattern) if /^\d+$/.match?(pattern)
    if loc
      redirect_to(action: "show_location", id: loc.id)
    else
      query = create_query(
        :Location, :pattern_search,
        pattern: Location.user_name(@user, pattern)
      )
      show_selected_locations(query, link_all_sorts: true)
    end
  end

  # Displays matrix of advanced search results.
  def advanced_search
    return if handle_advanced_search_invalid_q_param?

    query = find_query(:Location)
    show_selected_locations(query, link_all_sorts: true)
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    redirect_to(controller: :observer, action: :advanced_search_form)
  end

  # Show selected search results as a list with 'list_locations' template.
  def show_selected_locations(query, args = {})
    @links ||= []

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["name",        :sort_by_name.t],
      ["created_at",  :sort_by_created_at.t],
      [(query.flavor == :by_rss_log ? "rss_log" : "updated_at"),
       :sort_by_updated_at.t],
      ["num_views", :sort_by_num_views.t]
    ]

    # Add "show observations" link if this query can be coerced into an
    # observation query.
    @links << coerced_query_link(query, Observation)

    # Add "show descriptions" link if this query can be coerced into an
    # location description query.
    if query.coercable?(:LocationDescription)
      @links << [:show_objects.t(type: :description),
                 add_query_param({ action: :index_location_description },
                                 query)]
    end

    # Restrict to subset within a geographical region (used by map
    # if it needed to stuff multiple locations into a single marker).
    query = restrict_query_to_box(query)

    # Get matching *undefined* locations.
    @undef_location_format = User.current_location_format
    if (query2 = coerce_query_for_undefined_locations(query))
      select_args = {
        group: "observations.where",
        select: "observations.where AS w, COUNT(observations.id) AS c"
      }
      if args[:link_all_sorts]
        select_args[:order] = "c DESC"
        # (This tells it to say "by name" and "by frequency" by the subtitles.
        # If user has explicitly selected the order, then this is disabled.)
        @default_orders = true
      end
      @undef_pages = paginate_letters(:letter2,
                                      :page2,
                                      args[:num_per_page] || 50)
      @undef_data = query2.select_rows(select_args)
      @undef_pages.used_letters = @undef_data.map { |row| row[0][0, 1] }.uniq
      if (letter = params[:letter2].to_s.downcase) != ""
        @undef_data = @undef_data.select do |row|
          row[0][0, 1].downcase == letter
        end
      end
      @undef_pages.num_total = @undef_data.length
      @undef_data = @undef_data[@undef_pages.from..@undef_pages.to]
    else
      @undef_pages = nil
      @undef_data = nil
    end

    # Paginate the defined locations using the usual helper.
    args[:always_index] = @undef_pages&.num_total&.positive?
    args[:action] = args[:action] || "list_locations"
    show_index_of_objects(query, args)
  end

  # Map results of a search or index.
  def map_locations
    @query = find_or_create_query(:Location)

    apply_content_filters(@query)

    @title = if @query.flavor == :all
               :map_locations_global_map.t
             else
               :map_locations_title.t(locations: @query.title)
             end
    @query = restrict_query_to_box(@query)
    @timer_start = Time.current
    columns = %w[name north south east west].map { |x| "locations.#{x}" }
    args = { select: "DISTINCT(locations.id), #{columns.join(", ")}" }
    @locations = @query.select_rows(args).map do |id, *the_rest|
      MinimalMapLocation.new(id, *the_rest)
    end
    @num_results = @locations.count
    @timer_end = Time.current
  end

  # Try to turn this into a query on observations.where instead.
  # Yes, still a kludge, but a little better than tweaking SQL by hand...
  def coerce_query_for_undefined_locations(query)
    model  = :Observation
    flavor = query.flavor
    args   = query.params.dup
    result = nil

    # Select only observations with undefined location.
    if !args[:where]
      args[:where] = []
    elsif !args[:where].is_a?(Array)
      args[:where] = [args[:where]]
    end
    args[:where] << "observations.location_id IS NULL"

    # "By name" means something different to observation.
    if args[:by].blank? ||
       (args[:by] == "name")
      args[:by] = "where"
    end

    case query.flavor

    # These are okay as-is.
    when :all, :by_user
      true

    # Simple coercions.
    when :with_observations
      flavor = :all
    when :with_observations_by_user
      flavor = :by_user
    when :with_observations_for_project
      flavor = :for_project
    when :with_observations_in_set
      flavor = :in_set
    when :with_observations_in_species_list
      flavor = :in_species_list

    # Temporarily kludge in pattern search the old way.
    when :pattern_search
      flavor = :all
      search = query.google_parse(args[:pattern])
      args[:where] += query.google_conditions(search, "observations.where")
      args.delete(:pattern)

    # when :regexp_search  ### NOT SURE WHAT DO FOR THIS

    # None of the rest make sense.
    else
      flavor = nil
    end

    # These are only used to create title, which isn't used,
    # they just get in the way.
    args.delete(:old_title)
    args.delete(:old_by)

    # Create query if okay.  (Still need to tweak select and group clauses.)
    if flavor
      result = create_query(model, flavor, args)

      # Also make sure it doesn't reference locations anywhere.  This would
      # presumably be the result of customization of one of the above flavors.
      result = nil if /\Wlocations\./.match?(result.query)
    end

    result
  end

  ##############################################################################
  #
  #  :section: Description Searches and Indexes
  #
  ##############################################################################

  # Displays a list of selected locations, based on current Query.
  def index_location_description
    query = find_or_create_query(:LocationDescription, by: params[:by])
    show_selected_location_descriptions(query, id: params[:id].to_s,
                                               always_index: true)
  end

  # Displays a list of all location_descriptions.
  def list_location_descriptions
    query = create_query(:LocationDescription, :all, by: :name)
    show_selected_location_descriptions(query)
  end

  # Display list of location_descriptions that a given user is author on.
  def location_descriptions_by_author
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:LocationDescription, :by_author, user: user)
    show_selected_location_descriptions(query)
  end

  # Display list of location_descriptions that a given user is editor on.
  def location_descriptions_by_editor
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:LocationDescription, :by_editor, user: user)
    show_selected_location_descriptions(query)
  end

  # Show selected search results as a list with 'list_locations' template.
  def show_selected_location_descriptions(query, args = {})
    store_query_in_session(query)
    @links ||= []
    args = {
      action: :list_location_descriptions,
      num_per_page: 50
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["name",        :sort_by_name.t],
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t],
      ["num_views",   :sort_by_num_views.t]
    ]

    # Add "show locations" link if this query can be coerced into an
    # observation query.
    @links << coerced_query_link(query, Location)

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
    loc_id = params[:id].to_s
    desc_id = params[:desc]
    @location = find_or_goto_index(Location, loc_id)
    return unless @location

    @canonical_url = "#{MO.http_domain}/location/show_location/"\
                     "#{@location.id}"

    # Load default description if user didn't request one explicitly.
    desc_id = @location.description_id if desc_id.blank?
    if desc_id.blank?
      @description = nil
    elsif (@description = LocationDescription.safe_find(desc_id))
      @description = nil unless in_admin_mode? || @description.is_reader?(@user)
    else
      flash_error(:runtime_object_not_found.t(type: :description,
                                              id: desc_id))
    end

    update_view_stats(@location)
    update_view_stats(@description) if @description

    # Get a list of projects the user can create drafts for.
    @projects = @user&.projects_member&.select do |project|
      @location.descriptions.none? { |d| d.belongs_to_project?(project) }
    end
  end

  # Show just a LocationDescription.
  def show_location_description
    store_location
    pass_query_params
    @description = find_or_goto_index(LocationDescription, params[:id].to_s)
    return unless @description

    @canonical_url = "#{MO.http_domain}/location/show_location_description/"\
                     "#{@description.id}"
    # Public or user has permission.
    if in_admin_mode? || @description.is_reader?(@user)
      @location = @description.location
      update_view_stats(@description)

      # Get a list of projects the user can create drafts for.
      @projects = @user&.projects_member&.select do |project|
        @location.descriptions.none? { |d| d.belongs_to_project?(project) }
      end

    # User doesn't have permission to see this description.
    elsif @description.source_type == :project
      flash_error(:runtime_show_draft_denied.t)
      if (project = @description.project)
        redirect_to(controller: :project, action: :show_project,
                    id: project.id)
      else
        redirect_to(action: :show_location, id: @description.location_id)
      end
    else
      flash_error(:runtime_show_description_denied.t)
      redirect_to(action: :show_location, id: @description.location_id)
    end
  end

  # Show past version of Location.  Accessible only from show_location page.
  def show_past_location
    store_location
    pass_query_params
    @location = find_or_goto_index(Location, params[:id].to_s)
    return unless @location

    if params[:version]
      @location.revert_to(params[:version].to_i)
    else
      flash_error(:show_past_location_no_version.t)
      redirect_to(action: :show_location, id: @location.id)
    end
  end

  # Show past version of LocationDescription.  Accessible only from
  # show_location_description page.
  def show_past_location_description
    store_location
    pass_query_params
    @description = find_or_goto_index(LocationDescription, params[:id].to_s)
    return unless @description

    @location = @description.location
    if params[:merge_source_id].blank?
      @description.revert_to(params[:version].to_i)
    else
      @merge_source_id = params[:merge_source_id]
      version = LocationDescription::Version.find(@merge_source_id)
      @old_parent_id = version.location_description_id
      subversion = params[:version]
      if subversion.present? &&
         (version.version != subversion.to_i)
        version = LocationDescription::Version.
                  find_by_version_and_location_description_id(
                    params[:version], @old_parent_id
                  )
      end
      @description.clone_versioned_model(version, @description)
    end
  end

  # Go to next location: redirects to show_location.
  def next_location
    redirect_to_next_object(:next, Location, params[:id].to_s)
  end

  # Go to previous location: redirects to show_location.
  def prev_location
    redirect_to_next_object(:prev, Location, params[:id].to_s)
  end

  # Go to next location: redirects to show_location.
  def next_location_description
    redirect_to_next_object(:next, LocationDescription, params[:id].to_s)
  end

  # Go to previous location: redirects to show_location.
  def prev_location_description
    redirect_to_next_object(:prev, LocationDescription, params[:id].to_s)
  end

  ##############################################################################
  #
  #  :section: Create/Edit Location
  #
  ##############################################################################
  def create_location
    store_location
    pass_query_params

    # Original name passed in when arrive here with express purpose of
    # defining a given location. (e.g., clicking on "define this location",
    # or after create_observation with unknown location)
    # Note: names are in user's preferred order unless explicitly otherwise.)
    @original_name = params[:where]

    # Previous value of place name: ignore warnings if unchanged
    # (i.e., resubmit same name).
    @approved_name = params[:approved_where]

    # This is the latest value of place name.
    @display_name = begin
                      params[:location][:display_name].strip_squeeze
                    rescue StandardError
                      @original_name
                    end

    # Where to return after successfully creating location.
    @set_observation  = params[:set_observation]
    @set_species_list = params[:set_species_list]
    @set_user         = params[:set_user]
    @set_herbarium    = params[:set_herbarium]

    # Render a blank form.
    if request.method != "POST"
      user_name = Location.user_name(@user, @display_name)
      if @display_name
        @dubious_where_reasons = Location.
                                 dubious_name?(user_name, provide_reasons: true)
      end
      @location = Location.new
      geocoder = Geocoder.new(user_name)
      if geocoder.valid
        @location.display_name = @display_name
        @location.north = geocoder.north
        @location.south = geocoder.south
        @location.east = geocoder.east
        @location.west = geocoder.west
      else
        @location.display_name = ""
        @location.north = 80
        @location.south = -80
        @location.east = 89
        @location.west = -89
      end

    # Submit form.
    else
      # Set to true below if created successfully, or if a matching location
      # already exists.  In either case, we're done with this form.
      done = false

      # Look to see if the display name is already in use.
      # If it is then just use that location and ignore the other values.
      # Probably should be smarter with warnings and merges and such...
      db_name = Location.user_name(@user, @display_name)
      @location = Location.find_by_name_or_reverse_name(db_name)

      # Location already exists.
      if @location
        flash_warning(:runtime_location_already_exists.t(name: @display_name))
        done = true

      # Need to create location.
      else
        @location = Location.new(whitelisted_location_params)
        @location.display_name = @display_name # (strip_squozen)

        # Validate name.
        @dubious_where_reasons = []
        if @display_name != @approved_name
          @dubious_where_reasons = Location.dubious_name?(
            db_name, provide_reasons: true
          )
        end

        if @dubious_where_reasons.empty?
          if @location.save
            flash_notice(:runtime_location_success.t(id: @location.id))
            done = true
          else
            # Failed to create location
            flash_object_errors(@location)
          end
        end
      end

      # If done, update any observations at @display_name,
      # and set user's primary location if called from profile.
      if done
        if @original_name.present?
          db_name = Location.user_name(@user, @original_name)
          Observation.define_a_location(@location, db_name)
          SpeciesList.define_a_location(@location, db_name)
        end
        if @set_observation
          if unshown_notifications?(@user, :naming)
            redirect_to(controller: :observer, action: :show_notifications)
          else
            redirect_to(controller: :observer,
                        action: :show_observation,
                        id: @set_observation)
          end
        elsif @set_species_list
          redirect_to(controller: :species_list, action: :show_species_list,
                      id: @set_species_list)
        elsif @set_herbarium
          if (herbarium = Herbarium.safe_find(@set_herbarium))
            herbarium.location = @location
            herbarium.save
            redirect_to(herbarium_path(@set_herbarium))
          end
        elsif @set_user
          if (user = User.safe_find(@set_user))
            user.location = @location
            user.save
            redirect_to(controller: :observer,
                        action: :show_user,
                        id: @set_user)
          end
        else
          redirect_to(controller: :location,
                      action: :show_location,
                      id: @location.id)
        end
      end
    end
  end

  def edit_location
    store_location
    pass_query_params
    @location = find_or_goto_index(Location, params[:id].to_s)
    return unless @location

    params[:location] ||= {}
    @display_name = @location.display_name
    post_edit_location if request.method == "POST"
  end

  def post_edit_location
    @display_name = params[:location][:display_name].strip_squeeze
    db_name = Location.user_name(@user, @display_name)
    merge = Location.find_by_name_or_reverse_name(db_name)
    if merge && merge != @location
      post_edit_location_merge(merge)
    else
      post_edit_location_change(db_name)
    end
  end

  # Merge this location with another.
  def post_edit_location_merge(merge)
    if !@location.mergable? && merge.mergable?
      @location, merge = merge, @location
    end
    if in_admin_mode? || @location.mergable?
      old_name = @location.display_name
      new_name = merge.display_name
      merge.merge(@location)
      merge.save if merge.changed?
      @location = merge
      flash_notice(:runtime_location_merge_success.t(this: old_name,
                                                     that: new_name))
      redirect_to(@location.show_link_args)
    else
      redirect_with_query(controller: :observer,
                          action: :email_merge_request,
                          type: :Location,
                          old_id: @location.id,
                          new_id: merge.id)
    end
  end

  # Just change this location in place.
  def post_edit_location_change(db_name)
    @dubious_where_reasons = []
    @location.notes = params[:location][:notes].to_s.strip
    @location.locked = params[:location][:locked] == "1" if in_admin_mode?
    if !@location.locked || in_admin_mode?
      @location.north = params[:location][:north] if params[:location][:north]
      @location.south = params[:location][:south] if params[:location][:south]
      @location.east  = params[:location][:east]  if params[:location][:east]
      @location.west  = params[:location][:west]  if params[:location][:west]
      @location.high  = params[:location][:high]  if params[:location][:high]
      @location.low   = params[:location][:low]   if params[:location][:low]
      @location.display_name = @display_name
      if @display_name != params[:approved_where]
        @dubious_where_reasons = Location.dubious_name?(
          db_name, provide_reasons: true
        )
      end
    end
    return unless @dubious_where_reasons.empty?

    if !@location.changed?
      flash_warning(:runtime_edit_location_no_change.t)
      redirect_to(action: :show_location, id: @location.id)
    elsif !@location.save
      flash_object_errors(@location)
    else
      flash_notice(:runtime_edit_location_success.t(id: @location.id))
      redirect_to(@location.show_link_args)
    end
  end

  def create_location_description
    store_location
    pass_query_params
    @location = Location.find(params[:id].to_s)
    @licenses = License.current_names_and_ids
    @description = LocationDescription.new
    @description.location = @location

    # Render a blank form.
    if request.method == "GET"
      initialize_description_source(@description)

    # Create new description.
    else
      @description.attributes = whitelisted_location_description_params

      if @description.valid?
        initialize_description_permissions(@description)
        @description.save

        # Log action in parent location.
        @description.location.log(:log_description_created,
                                  user: @user.login, touch: true,
                                  name: @description.unique_partial_format_name)

        flash_notice(
          :runtime_location_description_success.t(id: @description.id)
        )
        redirect_to(action: :show_location_description,
                    id: @description.id)

      else
        flash_object_errors(@description)
      end
    end
  end

  def edit_location_description
    store_location
    pass_query_params
    @description = LocationDescription.find(params[:id].to_s)
    @licenses = License.current_names_and_ids

    # check_description_edit_permission is partly broken.
    # It, LocationController, and NameController need repairs.
    # See https://www.pivotaltracker.com/story/show/174737948
    if !check_description_edit_permission(@description, params[:description])
      # already redirected

    elsif request.method == "POST"
      @description.attributes = whitelisted_location_description_params

      # Modify permissions based on changes to the two "public" checkboxes.
      modify_description_permissions(@description)

      # No changes made.
      if !@description.changed?
        flash_warning(:runtime_edit_location_description_no_change.t)
        redirect_to(action: :show_location_description,
                    id: @description.id)

      # There were error(s).
      elsif !@description.save
        flash_object_errors(@description)

      # Updated successfully.
      else
        flash_notice(
          :runtime_edit_location_description_success.t(id: @description.id)
        )

        # Log action in parent location.
        @description.location.log(:log_description_updated,
                                  user: @user.login, touch: true,
                                  name: @description.unique_partial_format_name)

        # Delete old description after resolving conflicts of merge.
        if (params[:delete_after] == "true") &&
           (old_desc = LocationDescription.safe_find(params[:old_desc_id]))
          v = @description.versions.latest
          v.merge_source_id = old_desc.versions.latest.id
          v.save
          if !in_admin_mode? && !old_desc.is_admin?(@user)
            flash_warning(:runtime_description_merge_delete_denied.t)
          else
            flash_notice(:runtime_description_merge_deleted.
                           t(old: old_desc.partial_format_name))
            @description.location.log(
              :log_object_merged_by_user,
              user: @user.login, touch: true,
              from: old_desc.unique_partial_format_name,
              to: @description.unique_partial_format_name
            )
            old_desc.destroy
          end
        end

        redirect_to(action: :show_location_description,
                    id: @description.id)
      end
    end
  end

  def destroy_location_description
    pass_query_params
    @description = LocationDescription.find(params[:id].to_s)
    if in_admin_mode? || @description.is_admin?(@user)
      flash_notice(:runtime_destroy_description_success.t)
      @description.location.log(:log_description_destroyed,
                                user: @user.login, touch: true,
                                name: @description.unique_partial_format_name)
      @description.destroy
      redirect_with_query(action: :show_location,
                          id: @description.location_id)
    else
      flash_error(:runtime_destroy_description_not_admin.t)
      if in_admin_mode? || @description.is_reader?(@user)
        redirect_with_query(action: :show_location_description,
                            id: @description.id)
      else
        redirect_with_query(action: :show_location,
                            id: @description.location_id)
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
    @where = Location.user_name(@user, params[:where].to_s)

    # Split list of all locations into "matches" and "non-matches".  Try
    # matches in the following order:
    #   1) all that start with full "where" string
    #   2) all that start with everything in "where" up to the comma
    #   3) all that start with the first word in "where"
    #   4) there just aren't any matches, give up
    all = Location.all.order("name")
    @matches, @others = (
      split_out_matches(all, @where) ||
      split_out_matches(all, @where.split(",").first) ||
      split_out_matches(all, @where.split(" ").first) ||
      [nil, all]
    )
  end

  # Split up +list+ into those that start with +substring+ and those that
  # don't.  If none match, then return nil.
  def split_out_matches(list, substring)
    matches = list.select do |loc|
      (loc.name.to_s[0, substring.length] == substring)
    end
    if matches.empty?
      nil
    else
      [matches, list - matches]
    end
  end

  def reverse_name_order
    if (location = Location.safe_find(params[:id].to_s))
      location.name = Location.reverse_name(location.name)
      location.save
    end
    redirect_to(action: :show_location, id: params[:id].to_s)
  end

  # Adds the Observation's associated with <tt>obs.where == params[:where]</tt>
  # into the given Location.  Linked from +list_merge_options+, I think.
  def add_to_location
    location = find_or_goto_index(Location, params[:location])
    return unless location

    where = begin
              params[:where].strip_squeeze
            rescue StandardError
              ""
            end
    if where.present? &&
       update_observations_by_where(location, where)
      flash_notice(
        :runtime_location_merge_success.t(this: where,
                                          that: location.display_name)
      )
    end
    redirect_to(action: :list_locations)
  end

  # Help for locations
  def help; end

  # Move all the Observation's with a given +where+ into a given Location.
  def update_observations_by_where(location, given_where)
    success = true
    # observations = Observation.find_all_by_where(given_where)
    observations = Observation.where(where: given_where)
    count = 3
    observations.each do |o|
      count += 1
      next if o.location_id

      o.location_id = location.id
      o.where = nil
      next if o.save

      flash_error(:runtime_location_merge_failed.t(name: o.unique_format_name))
      success = false
    end
    success
  end

  ##############################################################################

  private

  def whitelisted_location_params
    params.require(:location).
      permit(:display_name, :north, :west, :east, :south, :high, :low, :notes)
  end

  def whitelisted_location_description_params
    params.require(:description).
      permit(:source_type, :source_name, :project_id, :public_write, :public,
             :license_id, :gen_desc, :ecology, :species, :notes, :refs)
  end
end
