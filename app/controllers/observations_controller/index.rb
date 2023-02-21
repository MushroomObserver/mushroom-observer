# frozen_string_literal: true

# see observations_controller.rb
module ObservationsController::Index
  # Disable cop because method definition prevents a
  # Rails/LexicallyScopedActionFilter offense
  # https://docs.rubocop.org/rubocop-rails/cops_rails.html#railslexicallyscopedactionfilter
  def index # rubocop:disable Lint/UselessMethodDefinition
    super
  end

  ###########################################################################
  # index subactions:
  # methods called by #index via a dispatch table in ObservationController

  # Displays matrix of selected Observations (based on current Query).
  # NOTE: Why are all the :id params converted .to_s below?
  def index_observation
    query = find_or_create_query(:Observation, by: params[:by])
    show_selected_observations(
      query, id: params[:id].to_s, always_index: true
    )
  end

  # Displays matrix of all Observation's, sorted by date.
  def list_observations
    query = create_query(:Observation, :all, by: :date)
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

  # Displays matrix of User's Observations, by date.
  def observations_by_user
    return unless (
      user = find_or_goto_index(User, params[:user])
    )

    query = create_query(:Observation, :by_user, user: user)
    show_selected_observations(query)
  end

  # Displays matrix of Observations at a Location, by date.
  def observations_at_location
    return unless (
      location = find_or_goto_index(Location, params[:location].to_s)
    )

    query = create_query(:Observation, :at_location, location: location)
    show_selected_observations(query)
  end

  # Display matrix of Observations whose "where" matches a string.
  def observations_at_where
    where = params[:where].to_s
    params[:location] = where
    query = create_query(:Observation, :at_where,
                         user_where: where,
                         location: Location.user_name(@user, where))
    show_selected_observations(query, always_index: 1)
  end

  # Display matrix of Observations attached to a given project.
  def observations_for_project
    return unless (
      project = find_or_goto_index(Project, params[:project].to_s)
    )

    query = create_query(:Observation, :for_project, project: project)
    show_selected_observations(query, always_index: 1)
  end

  # Display matrix of Observations whose notes, etc. match a string pattern.
  def observation_search
    pattern = params[:pattern].to_s
    if pattern.match?(/^\d+$/) && (observation = Observation.safe_find(pattern))
      redirect_to(permanent_observation_path(observation.id))
    else
      render_observation_search_results(pattern)
    end
  end

  def render_observation_search_results(pattern)
    search = PatternSearch::Observation.new(pattern)
    if search.errors.any?
      search.errors.each do |error|
        flash_error(error.to_s)
      end
      if params[:needs_id]
        redirect_to({ controller: "/observations/identify", action: :index,
                      q: get_query_param })
      else
        render("index", location: observations_path)
      end
    else
      @suggest_alternate_spellings = search.query.params[:pattern]
      if params[:needs_id]
        redirect_to({ controller: "/observations/identify", action: :index,
                      q: get_query_param(search.query) })
      else
        show_selected_observations(
          search.query, no_hits_title: :title_for_observation_search.t
        )
      end
    end
  end

  # Displays matrix of advanced search results.
  def advanced_search
    if params[:name] || params[:location] || params[:user] || params[:content]
      query = create_advanced_search_query(params)
    else
      return if handle_advanced_search_invalid_q_param?

      query = find_query(:Observation)
    end
    show_selected_observations(query)
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    redirect_to(search_advanced_path)
  end

  ###########################################################################

  # Show selected search results as a matrix with "index" template.
  def show_selected_observations(query, args = {})
    store_query_in_session(query)

    args = define_index_args(query, args)

    # Restrict to subset within a geographical region (used by map
    # if it needed to stuff multiple locations into a single marker).
    query = restrict_query_to_box(query)

    # make @query available to the :index template for query-dependent tabs
    @query = query

    show_index_of_objects(query, args)
  end

  private

  def default_index_subaction
    list_observations
  end

  def create_advanced_search_query(params)
    search = {}
    search[:name] = params[:name] if params[:name].present?
    search[:location] = params[:location] if params[:location].present?
    search[:user] = params[:user] if params[:user].present?
    search[:content] = params[:content] if params[:content].present?
    search[:search_location_notes] = params[:search_location_notes].present?
    create_query(:Observation, :advanced_search, search)
  end

  def parents(name_str)
    names = Name.where(id: name_str).to_a
    names = Name.where(search_name: name_str).to_a if names.empty?
    names = Name.where(text_name: name_str).to_a if names.empty?
    names.map { |name| name.approved_name.parents }.flatten.map(&:id).uniq
  end

  def define_index_args(query, args)
    args = { controller: "/observations",
             action: :index,
             matrix: true,
             include: [:name, :location, :user, :rss_log,
                       { thumb_image: :image_votes }] }.merge(args)

    # Add some alternate sorting criteria.
    links = [
      ["name", :sort_by_name.t],
      ["date", :sort_by_date.t],
      ["user", :sort_by_user.t],
      ["created_at", :sort_by_posted.t],
      [(query.flavor == :by_rss_log ? "rss_log" : "updated_at"),
       :sort_by_updated_at.t],
      ["confidence", :sort_by_confidence.t],
      # ["needs_id", :sort_by_needs_id.t],
      ["thumbnail_quality", :sort_by_thumbnail_quality.t],
      ["num_views", :sort_by_num_views.t]
    ]
    args[:sorting_links] = links

    # Paginate by letter if sorting by user.
    case query.params[:by]
    when "user", "reverse_user"
      args[:letters] = "users.login"
    # Paginate by letter if sorting by name.
    when "name", "reverse_name"
      args[:letters] = "names.sort_name"
    end
    args
  end
end
