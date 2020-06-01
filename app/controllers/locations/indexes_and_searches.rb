# frozen_string_literal: true

# see app/controllers/locations_controller.rb
class LocationsController

  ##############################################################################
  #
  #  :section: Indexes and Searches
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
    # redirect_to controller: :search, action: :advanced_search_form
    redirect_to search_advanced_search_form_path
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
    # @links << coerced_query_link(query, Observation)
    # NIMMO: Haven't figured out how to get coerced_query_link
    # (from application_controller) to work with paths. Building link here.
    if query&.coercable?(:Observation)
      @links << [:show_objects.t(type: :observation),
                 observations_index_observation_path(q: get_query_param)]

    # Add "show descriptions" link if this query can be coerced into an
    # location description query.
    elsif query.coercable?(:LocationDescription)
      # @links << [:show_objects.t(type: :description),
      #            add_query_param(
      #              { controller: :location_descriptions_controller,
      #                action: :index_location_description },
      #              query
      #            )]
      @links << [:show_objects.t(type: :description),
        locations_description_index_path(
          q: get_query_param
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
    args[:always_index] = @undef_pages&.num_total&.positive?
    args[:action] = args[:action] || "index"
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

end
