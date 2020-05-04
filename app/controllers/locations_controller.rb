# frozen_string_literal: true

require "geocoder"

# Location controller.
class LocationsController < ApplicationController
  include DescriptionControllerHelpers

  before_action :login_required, except: [
    :advanced_search,
    :help,
    :index,
    :index_location,
    :list_by_country,
    :list_countries,
    :list_locations,
    :location_search,
    :locations_by_editor,
    :locations_by_user,
    :map_locations,
    :next_location,
    :prev_location,
    :show,
    :show_location,
    :show_next,
    :show_prev,
    :show_past_location
  ]

  before_action :disable_link_prefetching, except: [
    :create_location,
    :edit,
    :edit_location,
    :new,
    :show,
    :show_location,
    :show_past_location
  ]

  before_action :require_successful_user, only: [
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
  def index
    query = create_query(:Location, :all, by: :name)
    show_selected_locations(query, link_all_sorts: true)
  end

  alias_method :list_locations, :index

  # Display list of locations that a given user is author on.
  def locations_by_user
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:Location, :by_user, user: user)
    show_selected_locations(query, link_all_sorts: true)
  end

  # Display list of locations that a given user is editor on.
  # :norobots:
  def locations_by_editor
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(:Location, :by_editor, user: user)
    show_selected_locations(query)
  end

  # Displays a list of locations matching a given string.
  # :norobots:
  def location_search
    query = create_query(
      :Location, :pattern_search,
      pattern: Location.user_name(@user, params[:pattern].to_s)
    )
    show_selected_locations(query, link_all_sorts: true)
  end

  # Displays matrix of advanced search results.
  def advanced_search
    query = find_query(:Location)
    show_selected_locations(query, link_all_sorts: true)
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    redirect_to(
      controller: :search,
      action: :advanced_search_form
    )
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
                 add_query_param(
                   { controller: :location_descriptions_controller,
                     action: :index_location_description },
                   query
                 )]
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
    args[:always_index] = (@undef_pages&.num_total&.positive?)
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
  #  :section: Show Location
  #
  ##############################################################################

  # Show a Location and one of its LocationDescription's, including a map.
  def show
    store_location
    pass_query_params
    clear_query_in_session

    # Load Location and LocationDescription along with a bunch of associated
    # objects.
    loc_id = params[:id].to_s
    desc_id = params[:desc]
    @location = find_or_goto_index(Location, loc_id)
    return unless @location

    @canonical_url = "#{MO.http_domain}/locations/#{@location.id}"

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

  alias_method :show_location, :show

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
      redirect_to(
        action: :show,
        id: @location.id
      )
    end
  end

  # Go to next location: redirects to show_location.
  def show_next
    redirect_to_next_object(:next, Location, params[:id].to_s)
  end

  alias_method :next_location, :show_next

  # Go to previous location: redirects to show_location.
  def show_prev
    redirect_to_next_object(:prev, Location, params[:id].to_s)
  end

  alias_method :prev_location, :show_prev

  ##############################################################################
  #
  #  :section: Create/Edit Location
  #
  ##############################################################################
  # TODO: NIMMO - this is an epic method, break it up
  def new
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
    user_name = Location.user_name(@user, @display_name)
    if @display_name
      @dubious_where_reasons = Location.
                               dubious_name?(user_name, true)
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

  end

  alias_method :create_location, :new

  # TODO: NIMMO - this is an epic method, break it up
  def create
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
        @dubious_where_reasons = Location.dubious_name?(db_name, true)
      end

      if @dubious_where_reasons.empty?
        if @location.save
          flash_notice(:runtime_location_success.t(id: @location.id))
          done = true
        else
          # Failed to create location
          flash_object_errors @location
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
          redirect_to(
            controller: :notifications,
            action: :show_notifications
          )
        else
          redirect_to(
            controller: :observations,
            action: :show_observation,
            id: @set_observation
          )
        end
      elsif @set_species_list
        redirect_to(
          controller: :species_lists,
          action: :show_species_list,
          id: @set_species_list
        )
      elsif @set_herbarium
        if (herbarium = Herbarium.safe_find(@set_herbarium))
          herbarium.location = @location
          herbarium.save
          redirect_to(
            controller: :herbaria,
            action: :show_herbarium,
            id: @set_herbarium
          )
        end
      elsif @set_user
        if (user = User.safe_find(@set_user))
          user.location = @location
          user.save
          redirect_to(
            controller: :users,
            action: :show_user,
            id: @set_user
          )
        end
      else
        redirect_to(
          controller: :locations,
          action: :show_location,
          id: @location.id
        )
      end
    end
  end

  # :prefetch: :norobots:
  def edit
    store_location
    pass_query_params
    @location = find_or_goto_index(Location, params[:id].to_s)
    return unless @location

    params[:location] ||= {}
    @display_name = @location.display_name
  end

  alias_method :edit_location, :edit

  def update
    store_location
    pass_query_params
    @location = find_or_goto_index(Location, params[:id].to_s)
    @display_name = params[:location][:display_name].strip_squeeze
    db_name = Location.user_name(@user, @display_name)
    merge = Location.find_by_name_or_reverse_name(db_name)
    if merge && merge != @location
      update_location_merge(merge)
    else
      update_location_change(db_name)
    end
  end

  alias_method :post_edit_location, :update

  private

  # Merge this location with another.
  def update_location_merge(merge)
    if !@location.mergable? && merge.mergable?
      @location, merge = merge, @location
    end
    if in_admin_mode? || @location.mergable?
      merge.merge(@location)
      merge.save if merge.changed?
      @location = merge
      redirect_to(
        @location.show_link_args
      )
    else
      redirect_with_query(
        controller: :email,
        action: :email_merge_request,
        type: :Location,
        old_id: @location.id,
        new_id: merge.id
      )
    end
  end

  # Just change this location in place.
  def update_location_change(db_name)
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
        @dubious_where_reasons = Location.dubious_name?(db_name, true)
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

  public

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
      unless o.save
        flash_error :runtime_location_merge_failed.t(name: o.unique_format_name)
        success = false
      end
    end
    success
  end

  ##############################################################################

  private

  def whitelisted_location_params
    params.require(:location).
      permit(:display_name, :north, :west, :east, :south, :high, :low, :notes)
  end

end
