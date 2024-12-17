# frozen_string_literal: true

module Query
  # Query's for Locations where Observation meets specified conditions
  class LocationWithObservations < Query::LocationBase
    include Query::Initializers::ContentFilters
    include Query::Initializers::Names
    include Query::Initializers::ObservationQueryDescriptions

    def parameter_declarations
      super.merge(
        old_by?: :string,
        date?: [:date],
        locations?: [:string],
        location?: Location,
        user_where?: :string,
        project?: Project,
        projects?: [:string],
        species_lists?: [:string],
        herbaria?: [:string],
        confidence?: [:float],
        is_collection_location?: :boolean,
        with_public_lat_lng?: :boolean,
        with_name?: :boolean,
        with_comments?: { boolean: [true] },
        with_sequences?: { boolean: [true] },
        with_notes?: :boolean,
        with_notes_fields?: [:string],
        notes_has?: :string,
        comments_has?: :string
      ).merge(content_filter_parameter_declarations(Observation)).
        merge(names_parameter_declarations).
        merge(consensus_parameter_declarations)
    end

    def initialize_flavor
      add_join(:observations)
      add_owner_and_time_stamp_conditions("observations")
      add_date_condition("observations.when", params[:date])
      initialize_name_parameters
      add_where_conditions
      initialize_association_parameters
      add_range_condition("observations.vote_cache", params[:confidence])
      initialize_boolean_parameters
      initialize_search_parameters
      initialize_content_filters(Observation)
      super
    end

    def add_where_conditions
      add_where_condition(:observations, params[:locations])
      add_at_location_parameter(:observations)
      add_search_condition("observations.where", params[:user_where])
    end

    def initialize_association_parameters
      add_id_condition(
        "project_observations.project_id",
        lookup_projects_by_name(params[:projects]),
        :observations, :project_observations
      )
      add_for_project_condition
      add_id_condition(
        "species_list_observations.species_list_id",
        lookup_species_lists_by_name(params[:species_lists]),
        :observations, :species_list_observations
      )
      add_id_condition(
        "herbarium_records.herbarium_id",
        lookup_herbaria_by_name(params[:herbaria]),
        :observations, :observation_herbarium_records, :herbarium_records
      )
    end

    def add_for_project_condition
      return if params[:project].blank?

      project = find_cached_parameter_instance(Project, :project)
      @title_tag = :query_title_for_project
      @title_args[:project] = project.title
      where << "project_observations.project_id = '#{params[:project]}'"
      where << "observations.is_collection_location IS TRUE"
      add_join(:observations, :project_observations)
    end

    def initialize_boolean_parameters
      initialize_is_collection_location_parameter
      initialize_with_public_lat_lng_parameter
      initialize_with_name_parameter
      initialize_with_notes_parameter
      add_with_notes_fields_condition(params[:with_notes_fields])
      add_join(:observations, :comments) if params[:with_comments]
      add_join(:observations, :sequences) if params[:with_sequences]
    end

    def initialize_is_collection_location_parameter
      add_boolean_condition(
        "observations.is_collection_location IS TRUE",
        "observations.is_collection_location IS FALSE",
        params[:is_collection_location]
      )
    end

    def initialize_with_public_lat_lng_parameter
      add_boolean_condition(
        "observations.lat IS NOT NULL AND observations.gps_hidden IS FALSE",
        "observations.lat IS NULL OR observations.gps_hidden IS TRUE",
        params[:with_public_lat_lng]
      )
    end

    def initialize_with_name_parameter
      genus = Name.ranks[:Genus]
      group = Name.ranks[:Group]
      add_boolean_condition(
        "names.`rank` <= #{genus} or names.`rank` = #{group}",
        "names.`rank` > #{genus} and names.`rank` < #{group}",
        params[:with_name],
        :observations, :names
      )
    end

    def initialize_with_notes_parameter
      add_boolean_condition(
        "observations.notes != #{escape(Observation.no_notes_persisted)}",
        "observations.notes  = #{escape(Observation.no_notes_persisted)}",
        params[:with_notes]
      )
    end

    def initialize_search_parameters
      add_search_condition(
        "observations.notes",
        params[:notes_has]
      )
      add_search_condition(
        "CONCAT(comments.summary,COALESCE(comments.comment,''))",
        params[:comments_has],
        :observations, :comments
      )
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :all, params_with_old_by_restored)
    end

    def title
      default = super
      with_observations_query_description || default
    end
  end
end
