# frozen_string_literal: true

# see observations_controller.rb
class ObservationsController
  module Index
    def index
      build_index_with_query
    end

    private

    # Default on home is :rss_log (:log_updated_at), not :date.
    # Maybe other filters should explicitly specify :date?
    # Then we could use default_sort_order above.
    # Or, set an "unfiltered sort order" method that defaults to this.
    def default_sort_order
      ::Query::Observations.default_order # :date
    end

    # Note all other filters of the obs index are sorted by date.
    def unfiltered_index_opts
      super.merge(query_args: { order_by: :rss_log })
    end

    # Searches come 1st because they may have the other params
    def index_active_params
      [:advanced_search, :pattern, :look_alikes, :related_taxa, :name,
       :by_user, :location, :where, :project, :species_list,
       :by, :q, :id].freeze
    end

    # Displays matrix of advanced search results.
    def advanced_search
      query = advanced_search_query
      # Have to check this here because we're not running the query yet.
      raise(:runtime_no_conditions.l) unless query&.params&.any?

      [query, {}]
    rescue StandardError => e
      flash_error(e.to_s) if e.present?
      redirect_to(search_advanced_path)
      [nil, {}]
    end

    def advanced_search_query
      if any_advanced_search_params_present?
        search = params.permit(*advanced_search_params).to_h
        create_query(:Observation, search)
      elsif handle_advanced_search_invalid_q_param?
        nil
      else
        find_query(:Observation)
      end
    end

    def any_advanced_search_params_present?
      advanced_search_params.any? { |k| params[k].present? }
    end

    def advanced_search_params
      params = Query::Observations.advanced_search_params
      return params if params.present?

      raise("Query::Observations.advanced_search_params is undefined.")
    end

    # Display matrix of Observations whose notes, etc. match a string pattern.
    def pattern
      pattern = params[:pattern].to_s
      if pattern.match?(/^\d+$/) &&
         (observation = Observation.safe_find(pattern))
        redirect_to(permanent_observation_path(observation.id))
      else
        return_pattern_search_results(pattern)
      end
    end

    # ObservationsIntegrationTest#
    # test_observation_pattern_search_with_correctable_pattern/
    def return_pattern_search_results(pattern)
      # NOTE: the **controller** method `create_query` applies user filters
      query = create_query(:Observation, pattern:)
      errors = query.validation_errors
      return render_pattern_search_error(errors) if errors.any?

      make_name_suggestions(query)

      if params[:needs_naming]
        redirect_to(
          identify_observations_path(q: get_query_param(query))
        )
        [nil, {}]
      else
        [query, {}]
      end
    end

    def make_name_suggestions(query)
      alternate_spellings = query.params[:pattern]
      return unless alternate_spellings && @objects.empty?

      @name_suggestions =
        Name.suggest_alternate_spellings(alternate_spellings)
    end

    def render_pattern_search_error(errors)
      errors.each { |error| flash_error(error.to_s) }
      if params[:needs_naming]
        redirect_to(identify_observations_path(q: get_query_param))
      end
      [nil, {}]
    end

    # Displays matrix of Observations with the given name proposed but not
    # actually that name.
    def look_alikes
      query = create_query(
        :Observation, names: { lookup: [params[:name]],
                               include_synonyms: true,
                               include_all_name_proposals: true,
                               exclude_consensus: true },
                      order_by: :confidence
      )
      [query, {}]
    end

    # Displays matrix of Observations of subtaxa of the parent of given name.
    def related_taxa
      query = create_query(
        :Observation, names: { lookup: parents(params[:name]),
                               include_subtaxa: true },
                      order_by: :confidence
      )
      [query, {}]
    end

    # Displays matrix of Observations with the given text_name (or search_name).
    def name
      query = create_query(
        :Observation, names: { lookup: [params[:name]],
                               include_synonyms: true },
                      order_by: :confidence
      )
      [query, {}]
    end

    def parents(name_str)
      names = Name.where(id: name_str).to_a
      names = Name.where(search_name: name_str).to_a if names.empty?
      names = Name.where(text_name: name_str).to_a if names.empty?
      names.map { |name| name.approved_name.parents }.flatten.map(&:id).uniq
    end

    # Displays matrix of User's Observations, by date.
    def by_user
      return unless (user = find_or_goto_index(User, params[:by_user]))

      query = create_query(:Observation, by_users: user)
      [query, {}]
    end

    # Displays matrix of Observations at a Location, by date.
    def location
      return unless (
        location = find_or_goto_index(Location, params[:location].to_s)
      )

      query = create_query(:Observation, locations: location)
      [query, {}]
    end

    # Display matrix of Observations whose "where" matches a string.
    # NOTE: We're passing the `search_where` param from advanced search to
    # AbstractModel's scope `search_where`, which searches two tables
    # (obs and loc) for the fuzzy match.
    def where
      where = params[:where].to_s
      query = create_query(:Observation, search_where: where)
      [query, { always_index: true }]
    end

    # Display matrix of Observations attached to a given project.
    def project
      return unless (
        project = find_or_goto_index(Project, params[:project].to_s)
      )

      query = create_query(:Observation, projects: project,
                                         order_by: "thumbnail_quality")
      @project = project
      [query, { always_index: true }]
    end

    # Display matrix of Observations attached to a given species_list.
    def species_list
      return unless (
        spl = find_or_goto_index(SpeciesList, params[:species_list].to_s)
      )

      query = create_query(:Observation, species_lists: spl)
      [query, { always_index: true }]
    end

    # Hook runs before template displayed. Must return query.
    def filtered_index_final_hook(query, _display_opts)
      store_query_in_session(query)
      query
    end

    def index_display_opts(opts, query)
      # We always want cached matrix boxes for observations if possible.
      # cache: true  will batch load the includes only for fragments not cached.
      opts = {
        matrix: true, cache: true,
        include: observation_index_includes
      }.merge(opts)

      # Offer pagination by letter only if the index has been filtered
      # and we're sorting by user or name.
      if query.params.except(:order_by).present? &&
         %w[user reverse_user name reverse_name].include?(
           query.params[:order_by]
         )
        opts[:letters] = true
      end

      opts
    end

    # An { images: } hash is necessary if we're adding the index carousels.
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
