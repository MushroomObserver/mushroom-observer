# frozen_string_literal: true

# see observations_controller.rb
# NOTE: Why are all the :id params converted .to_s here?
module ObservationsController::Index
  # Displays matrix of all Observations, sorted by date.
  def index
    # Note: searches execute show_selected_observations with possible redirect
    if params[:advanced_search].present?
      advanced_search and return
    elsif params[:pattern].present?
      observation_search and return
    end

    query = \
      if params[:look_alikes].present? && params[:name].present?
        observations_of_look_alikes
      elsif params[:related_taxa].present? && params[:name].present?
        observations_of_related_taxa
      elsif params[:name].present?
        observations_of_name
      elsif params[:user].present?
        observations_by_user
      elsif params[:location].present?
        observations_at_location
      elsif params[:where].present?
        observations_at_where
      elsif params[:project].present?
        observations_for_project
      elsif params[:by].present?
        index_observation
      else
        create_query(:Observation, :all, by: :date)
      end
    # Catch pattern search first; this may have the other params below
    # if params[:pattern].present?
    #   show_selected_observations(query)
    if params[:id].present?
      show_selected_observations(query, id: params[:id].to_s,
                                 always_index: true)
    elsif params[:where].present? || params[:project].present?
      show_selected_observations(query, always_index: true)
    else
      show_selected_observations(query)
    end
  end

  # Displays matrix of selected Observations (based on current Query).
  def index_observation
    query = find_or_create_query(:Observation, by: params[:by])
    # show_selected_observations(
    #   query, id: params[:id].to_s, always_index: true
    # )
  end

  # Of questionable utility?
  # Displays matrix of all Observations, alphabetically.
  def observations_by_name
    query = create_query(:Observation, :all, by: :name)
    # show_selected_observations(query)
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
    # show_selected_observations(query)
  end

  # Displays matrix of Observations with the given text_name (or search_name).
  def observations_of_name
    query = create_query(:Observation, :all,
                         names: [params[:name]],
                         include_synonyms: true,
                         by: :confidence)
    # show_selected_observations(query)
  end

  # Displays matrix of Observations of subtaxa of the parent of the given name.
  def observations_of_related_taxa
    query = create_query(:Observation, :all,
                         names: parents(params[:name]),
                         include_subtaxa: true,
                         by: :confidence)
    # show_selected_observations(query)
  end

  # Displays matrix of User's Observations, by date.
  def observations_by_user
    return unless (
      user = find_or_goto_index(User, params[:user].to_s)
    )

    query = create_query(:Observation, :by_user, user: user)
    # show_selected_observations(query)
  end

  # Displays matrix of Observations at a Location, by date.
  def observations_at_location
    return unless (
      location = find_or_goto_index(Location, params[:location].to_s)
    )

    query = create_query(:Observation, :at_location, location: location)
    # show_selected_observations(query)
  end

  # Display matrix of Observations whose "where" matches a string.
  def observations_at_where
    where = params[:where].to_s
    params[:location] = where
    query = create_query(:Observation, :at_where,
                         user_where: where,
                         location: Location.user_name(@user, where))
    # show_selected_observations(query, always_index: 1)
  end

  # Display matrix of Observations attached to a given project.
  def observations_for_project
    return unless (
      project = find_or_goto_index(Project, params[:project].to_s)
    )

    query = create_query(:Observation, :for_project, project: project)
    # show_selected_observations(query, always_index: 1)
  end

  # Display matrix of Observations whose notes, etc. match a string pattern.
  def observation_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) && (observation = Observation.safe_find(pattern))
      redirect_to(controller: :observations, action: :show,
                  id: observation.id)
    else
      search = PatternSearch::Observation.new(pattern)
      if search.errors.any?
        search.errors.each do |error|
          flash_error(error.to_s)
        end
        render(controller: :observations, action: :index)
      else
        @suggest_alternate_spellings = search.query.params[:pattern]
        show_selected_observations(
          search.query, no_hits_title: :title_for_observation_search.t
        )
      end
    end
  end

  # Displays matrix of advanced search results.
  def advanced_search
    if params[:name] || params[:location] || params[:user] || params[:content]
      search = {}
      search[:name] = params[:name] if params[:name].present?
      search[:location] = params[:location] if params[:location].present?
      search[:user] = params[:user] if params[:user].present?
      search[:content] = params[:content] if params[:content].present?
      search[:search_location_notes] = params[:search_location_notes].present?
      query = create_query(:Observation, :advanced_search, search)
    else
      return if handle_advanced_search_invalid_q_param?

      query = find_query(:Observation)
    end
    show_selected_observations(query)
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    redirect_to(searches_advanced_search_form_path)
  end

  # Show selected search results as a matrix with "index" template.
  def show_selected_observations(query, args = {})
    store_query_in_session(query)

    @links = define_index_links(query)
    args = define_index_args(query, args)

    # Restrict to subset within a geographical region (used by map
    # if it needed to stuff multiple locations into a single marker).
    query = restrict_query_to_box(query)

    show_index_of_objects(query, args)
  end

  private

  def parents(name_str)
    names = Name.where(id: name_str).to_a
    names = Name.where(search_name: name_str).to_a if names.empty?
    names = Name.where(text_name: name_str).to_a if names.empty?
    names.map { |name| name.approved_name.parents }.flatten.map(&:id).uniq
  end

  def define_index_links(query)
    @links ||= []

    # Add some extra links to the index user is sent to if they click on an
    # undefined location.
    if query.flavor == :at_where
      @links << [:list_observations_location_define.l,
                 { controller: :location, action: :create_location,
                   where: query.params[:user_where] }]
      @links << [:list_observations_location_merge.l,
                 { controller: :location, action: :list_merge_options,
                   where: query.params[:user_where] }]
      @links << [:list_observations_location_all.l,
                 { controller: :location, action: :list_locations }]
    end

    @links << [
      :show_object.t(type: :map),
      add_query_param(
        { controller: :observations, action: :map },
        query
      )
    ]

    @links << coerced_query_link(query, Location)
    @links << coerced_query_link(query, Name)
    @links << coerced_query_link(query, Image)

    @links << [
      :list_observations_add_to_list.t,
      add_query_param(
        { controller: :species_list, action: :add_remove_observations },
        query
      )
    ]

    @links << [
      :list_observations_download_as_csv.t,
      add_query_param(
        { controller: :observations, action: :download },
        query
      )
    ]
    @links
  end

  def define_index_args(query, args)
    args = { controller: :observations,
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
      ["thumbnail_quality", :sort_by_thumbnail_quality.t],
      ["num_views", :sort_by_num_views.t]
    ]
    args[:sorting_links] = links

    # Paginate by letter if sorting by user.
    if (query.params[:by] == "user") ||
       (query.params[:by] == "reverse_user")
      args[:letters] = "users.login"
    # Paginate by letter if sorting by name.
    elsif (query.params[:by] == "name") ||
          (query.params[:by] == "reverse_name")
      args[:letters] = "names.sort_name"
    end
    args
  end
end
