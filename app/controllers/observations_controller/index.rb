# frozen_string_literal: true

# see observations_controller.rb
class ObservationsController
  module Index
    def index
      build_index_with_query
    end

    private

    # Note all other filters of the obs index are sorted by date.
    def unfiltered_index_extra_args
      { by: :rss_log }
    end

    # Default on home is :rss_log (:log_updated_at), not :date.
    # Maybe other filters should explicitly specify :date?
    # Then we could use default_sort_order above.
    # Or, set an "unfiltered sort order" method that defaults to this.
    def default_sort_order
      ::Query::ObservationBase.default_order # :date
    end

    # Searches come 1st because they may have the other params
    def index_active_params
      [:advanced_search, :pattern, :look_alikes, :related_taxa, :name,
       :by_user, :location, :where, :project, :by, :q, :id].freeze
    end

    # Displays matrix of Observations with the given text_name (or search_name).
    def name
      query = create_query(:Observation, :all,
                           names: [params[:name]],
                           include_synonyms: true,
                           by: :confidence)
      index_selected(query)
    end

    # Displays matrix of Observations with the given name proposed but not
    # actually that name.
    def look_alikes
      query = create_query(:Observation, :all,
                           names: [params[:name]],
                           include_synonyms: true,
                           include_all_name_proposals: true,
                           exclude_consensus: true,
                           by: :confidence)
      index_selected(query)
    end

    # Displays matrix of Observations of subtaxa of the parent of given name.
    def related_taxa
      query = create_query(:Observation, :all,
                           names: parents(params[:name]),
                           include_subtaxa: true,
                           by: :confidence)
      index_selected(query)
    end

    def parents(name_str)
      names = Name.where(id: name_str).to_a
      names = Name.where(search_name: name_str).to_a if names.empty?
      names = Name.where(text_name: name_str).to_a if names.empty?
      names.map { |name| name.approved_name.parents }.flatten.map(&:id).uniq
    end

    # Displays matrix of User's Observations, by date.
    def by_user
      return unless (
        user = find_or_goto_index(User, params[:by_user])
      )

      query = create_query(:Observation, :by_user, user: user)
      index_selected(query)
    end

    # Displays matrix of Observations at a Location, by date.
    def location
      return unless (
        location = find_or_goto_index(Location, params[:location].to_s)
      )

      query = create_query(:Observation, :at_location, location: location)
      index_selected(query)
    end

    # Display matrix of Observations whose "where" matches a string.
    def where
      where = params[:where].to_s
      params[:location] = where
      query = create_query(:Observation, :at_where,
                           user_where: where,
                           location: Location.user_format(@user, where))
      index_selected(query, always_index: true)
    end

    # Display matrix of Observations attached to a given project.
    def project
      return unless (
        project = find_or_goto_index(Project, params[:project].to_s)
      )

      query = create_query(:Observation, :for_project, project: project)
      index_selected(query, always_index: true)
    end

    # Display matrix of Observations whose notes, etc. match a string pattern.
    def pattern
      pattern = params[:pattern].to_s
      if pattern.match?(/^\d+$/) &&
         (observation = Observation.safe_find(pattern))
        redirect_to(permanent_observation_path(observation.id))
      else
        render_pattern_search_results(pattern)
      end
    end

    def render_pattern_search_results(pattern)
      search = PatternSearch::Observation.new(pattern)
      return render_pattern_search_error(search) if search.errors.any?

      @suggest_alternate_spellings = search.query.params[:pattern]
      if params[:needs_naming]
        redirect_to(
          identify_observations_path(q: get_query_param(search.query))
        )
      else
        index_selected(search.query)
      end
    end

    def render_pattern_search_error(search)
      search.errors.each { |error| flash_error(error.to_s) }
      if params[:needs_naming]
        redirect_to(identify_observations_path(q: get_query_param))
      else
        render("index", location: observations_path)
      end
    end

    # Displays matrix of advanced search results.
    def advanced_search
      query = advanced_search_query
      return unless query

      index_selected(query)
    rescue StandardError => e
      flash_error(e.to_s) if e.present?
      redirect_to(search_advanced_path)
    end

    def advanced_search_query
      if params[:name] || params[:location] || params[:user] || params[:content]
        create_advanced_search_query(params)
      elsif handle_advanced_search_invalid_q_param?
        nil
      else
        find_query(:Observation)
      end
    end

    def create_advanced_search_query(params)
      search = {}
      [
        :name,
        :location,
        :user,
        :content,
        :search_location_notes
      ].each do |key|
        search[key] = params[key] if params[key].present?
      end
      create_query(:Observation, :advanced_search, search)
    end

    # Show selected search results as a matrix with "index" template.
    def index_selected(query, args = {})
      store_query_in_session(query)
      # Restrict to subset within a geographical region (used by map
      # if it needed to stuff multiple locations into a single marker).
      query = restrict_query_to_box(query)

      super
    end

    def index_display_args(args, query)
      # We always want cached matrix boxes for observations if possible.
      # cache: true  will batch load the includes only for fragments not cached.
      args = { controller: "/observations",
               action: :index,
               matrix: true, cache: true,
               include: observation_index_includes }.merge(args)

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

    # The { images: } hash is necessary for the index carousels.
    # :projects required by Bullet because it's needed to compute
    # `can_edit?` for an image.
    def observation_index_includes
      [observation_matrix_box_image_includes,
       :location, :name,
       { namings: :votes },
       :projects, :rss_log, :user]
    end
  end
end
