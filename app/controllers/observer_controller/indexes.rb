# frozen_string_literal: true

# see observer_controller.rb
class ObserverController
  # Displays matrix of selected Observation's (based on current Query).
  def index_observation
    query = find_or_create_query(:Observation, by: params[:by])
    show_selected_observations(query, id: params[:id].to_s, always_index: true)
  end

  # Displays matrix of all Observation's, sorted by date.
  def list_observations
    query = create_query(:Observation, :all, by: :date)
    show_selected_observations(query)
  end

  # Displays matrix of all Observation's, alphabetically.
  def observations_by_name
    query = create_query(:Observation, :all, by: :name)
    show_selected_observations(query)
  end

  # Displays matrix of Observations with the given name proposed but not
  # actually that name.
  def observations_of_look_alikes
    query = create_query(:Observation, :all,
                         names: [params[:name]],
                         include_synonyms: true,
                         include_all_name_proposals: true,
                         exclude_consensus: true,
                         by: :confidence)
    show_selected_observations(query)
  end

  # Displays matrix of Observations with the given text_name (or search_name).
  def observations_of_name
    query = create_query(:Observation, :all,
                         names: [params[:name]],
                         include_synonyms: true,
                         by: :confidence)
    show_selected_observations(query)
  end

  # Displays matrix of Observations of subtaxa of the parent of the given name.
  def observations_of_related_taxa
    query = create_query(:Observation, :all,
                         names: parents(params[:name]),
                         include_subtaxa: true,
                         by: :confidence)
    show_selected_observations(query)
  end

  def parents(name_str)
    names = Name.where(id: name_str).to_a
    names = Name.where(search_name: name_str).to_a if names.empty?
    names = Name.where(text_name: name_str).to_a if names.empty?
    names.map(&:parents).flatten.map(&:id).uniq
  end

  # Displays matrix of User's Observation's, by date.
  def observations_by_user
    return unless (user = find_or_goto_index(User, params[:id].to_s))

    query = create_query(:Observation, :by_user, user: user)
    show_selected_observations(query)
  end

  # Displays matrix of Observation's at a Location, by date.
  def observations_at_location
    return unless (location = find_or_goto_index(Location, params[:id].to_s))

    query = create_query(:Observation, :at_location, location: location)
    show_selected_observations(query)
  end

  alias show_location_observations observations_at_location

  # Display matrix of Observation's whose "where" matches a string.
  def observations_at_where
    where = params[:where].to_s
    params[:location] = where
    query = create_query(:Observation, :at_where,
                         user_where: where,
                         location: Location.user_name(@user, where))
    show_selected_observations(query, always_index: 1)
  end

  # Display matrix of Observation's attached to a given project.
  def observations_for_project
    return unless (project = find_or_goto_index(Project, params[:id].to_s))

    query = create_query(:Observation, :for_project, project: project)
    show_selected_observations(query, always_index: 1)
  end

  # Display matrix of Observation's whose notes, etc. match a string pattern.
  def observation_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) && (observation = Observation.safe_find(pattern))
      redirect_to(action: "show_observation", id: observation.id)
    else
      search = PatternSearch::Observation.new(pattern)
      if search.errors.any?
        search.errors.each do |error|
          flash_error(error.to_s)
        end
        render(action: :list_observations)
      else
        @suggest_alternate_spellings = search.query.params[:pattern]
        show_selected_observations(search.query)
      end
    end
  end

  # Show selected search results as a matrix with "list_observations" template.
  def show_selected_observations(query, args = {})
    store_query_in_session(query)
    @links ||= []
    args = {  action: "list_observations", matrix: true,
              include: [:name, :location, :user, :rss_log,
                        { thumb_image: :image_votes }] }.merge(args)

    # Add some extra links to the index user is sent to if they click on an
    # undefined location.
    if query.flavor == :at_where
      @links << [:list_observations_location_define.l,
                 { controller: "location", action: "create_location",
                   where: query.params[:user_where] }]
      @links << [:list_observations_location_merge.l,
                 { controller: "location", action: "list_merge_options",
                   where: query.params[:user_where] }]
      @links << [:list_observations_location_all.l,
                 { controller: "location", action: "list_locations" }]
    end

    # Add some alternate sorting criteria.
    links = [
      ["name", :sort_by_name.t],
      ["date", :sort_by_date.t],
      ["user", :sort_by_user.t],
      ["created_at", :sort_by_posted.t],
      [(query.flavor == :by_rss_log ? "rss_log" : "updated_at"),
       :sort_by_updated_at.t],
      ["confidence", :sort_by_confidence.t],
      ["thumbnail_quality", :sort_by_thumbnail_quality.t],
      ["num_views", :sort_by_num_views.t]
    ]
    args[:sorting_links] = links

    link = [
      :show_object.t(type: :map),
      add_query_param({ controller: "observer", action: "map_observations" },
                      query)
    ]
    @links << link

    @links << coerced_query_link(query, Location)
    @links << coerced_query_link(query, Name)
    @links << coerced_query_link(query, Image)

    @links << [
      :list_observations_add_to_list.t,
      add_query_param(
        { controller: "species_list", action: "add_remove_observations" },
        query
      )
    ]

    @links << [
      :list_observations_download_as_csv.t,
      add_query_param(
        { controller: "observer", action: "download_observations" },
        query
      )
    ]

    # Paginate by letter if sorting by user.
    if (query.params[:by] == "user") ||
       (query.params[:by] == "reverse_user")
      args[:letters] = "users.login"
    # Paginate by letter if sorting by name.
    elsif (query.params[:by] == "name") ||
          (query.params[:by] == "reverse_name")
      args[:letters] = "names.sort_name"
    end

    # Restrict to subset within a geographical region (used by map
    # if it needed to stuff multiple locations into a single marker).
    query = restrict_query_to_box(query)

    show_index_of_objects(query, args)
  end

  # Map results of a search or index.
  def map_observations
    @query = find_or_create_query(:Observation)
    apply_content_filters(@query)
    @title = :map_locations_title.t(locations: @query.title)
    @query = restrict_query_to_box(@query)
    @timer_start = Time.current

    # Get matching observations.
    locations = {}
    columns = %w[id lat long gps_hidden location_id].map do |x|
      "observations.#{x}"
    end
    args = {
      select: columns.join(", "),
      where: "observations.lat IS NOT NULL OR " \
             "observations.location_id IS NOT NULL"
    }
    @observations = \
      @query.select_rows(args).map do |id, lat, long, gps_hidden, loc_id|
        locations[loc_id.to_i] = nil if loc_id.present?
        lat = long = nil if gps_hidden == 1
        MinimalMapObservation.new(id, lat, long, loc_id)
      end

    unless locations.empty?
      # Eager-load corresponding locations.
      @locations = Location.connection.select_rows(%(
        SELECT id, name, north, south, east, west FROM locations
        WHERE id IN (#{locations.keys.sort.map(&:to_s).join(",")})
      )).map do |id, *the_rest|
        locations[id.to_i] = MinimalMapLocation.new(id, *the_rest)
      end
      @observations.each do |obs|
        obs.location = locations[obs.location_id] if obs.location_id
      end
    end
    @num_results = @observations.count
    @timer_end = Time.current
  end

  def print_labels
    query = find_query(:Observation)
    if query
      @labels = make_labels(query.results)
      render(action: "print_labels", layout: "printable")
    else
      flash_error(:runtime_search_has_expired.t)
      redirect_back_or_default("/")
    end
  end

  def download_observations
    @query = find_or_create_query(:Observation, by: params[:by])
    raise("no robots!") if browser.bot?

    query_params_set(@query)
    @format = params[:format] || "raw"
    @encoding = params[:encoding] || "UTF-8"
    download_observations_switch
  rescue StandardError => e
    flash_error("Internal error: #{e}", *e.backtrace[0..10])
  end

  private

  def download_observations_switch
    if params[:commit] == :CANCEL.l
      redirect_with_query(action: :index_observation, always_index: true)
    elsif params[:commit] == :DOWNLOAD.l
      render_observation_report
    elsif params[:commit] == :download_observations_print_labels.l
      render_labels
    end
  end

  def render_observation_report
    report = create_observation_report(
      query: @query, format: @format, encoding: @encoding
    )
    render_report(report)
  end

  def render_labels
    @labels = make_labels(@query.results)
    render(action: "print_labels", layout: "printable")
  end

  def create_observation_report(args)
    format = args[:format].to_s
    case format
    when "raw"
      ObservationReport::Raw.new(args)
    when "adolf"
      ObservationReport::Adolf.new(args)
    when "darwin"
      ObservationReport::Darwin.new(args)
    when "symbiota"
      ObservationReport::Symbiota.new(args)
    when "fundis"
      ObservationReport::Fundis.new(args)
    else
      raise("Invalid download type: #{format.inspect}")
    end
  end

  def render_report(report)
    send_data(report.body, {
      type: report.mime_type,
      charset: report.encoding,
      disposition: "attachment",
      filename: report.filename
    }.merge(report.header || {}))
  end

  def make_labels(observations)
    @fundis_herbarium = Herbarium.where(
      name: "Fungal Diversity Survey"
    ).first
    observations.map do |observation|
      make_label(observation)
    end
  end

  def make_label(observation)
    rows = label_data(observation)
    insert_fundis_id(rows, observation)
    rows
  end

  def label_data(observation)
    [
      ["MO #", observation.id],
      ["When", observation.when],
      ["Who", observation.collector_and_number],
      ["Where", observation.place_name_and_coordinates],
      ["What", observation.format_name.t],
      ["Notes", observation.notes_export_formatted.t]
    ]
  end

  def insert_fundis_id(rows, observation)
    return unless @fundis_herbarium

    fundis_record = observation.herbarium_records.where(
      herbarium: @fundis_herbarium
    ).first
    return unless fundis_record

    rows.insert(1, ["FunDiS #", fundis_record.accession_number])
  end
end
