# frozen_string_literal: true

module Query
  # Query's for Names where Observations meet specified conditions
  class NameWithObservations < Query::NameBase
    include Query::Initializers::ContentFilters
    include Query::Initializers::Names
    include Query::Initializers::ObservationQueryDescriptions

    def parameter_declarations
      super.merge(
        old_title?: :string,
        old_by?: :string,
        date?: [:date],
        ids?: [Observation],
        by_user?: User,
        project?: Project,
        projects?: [:string],
        species_list?: SpeciesList,
        herbaria?: [:string],
        confidence?: [:float],
        location?: Location,
        user_where?: :string,
        is_collection_location?: :boolean,
        with_public_lat_lng?: :boolean,
        with_name?: :boolean,
        with_sequences?: { boolean: [true] },
        with_notes_fields?: [:string],
        north?: :float,
        south?: :float,
        east?: :float,
        west?: :float
      ).merge(content_filter_parameter_declarations(Observation)).
        merge(consensus_parameter_declarations)
    end

    def initialize_flavor
      add_join(:observations)
      add_ids_condition("observations")
      add_owner_and_time_stamp_conditions("observations")
      add_by_user_condition("observations")
      add_date_condition("observations.when", params[:date])
      add_where_conditions
      initialize_association_parameters
      initialize_boolean_parameters
      initialize_search_parameters
      initialize_name_parameters(:observations)
      add_range_condition("observations.vote_cache", params[:confidence])
      add_bounding_box_conditions_for_observations
      initialize_content_filters(Observation)
      super
    end

    def initialize_association_parameters
      add_id_condition(
        "project_observations.project_id",
        lookup_projects_by_name(params[:projects]),
        :observations, :project_observations
      )
      add_for_project_condition
      add_in_species_list_condition
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
      add_join(:observations, :project_observations)
    end

    def add_in_species_list_condition
      return if params[:species_list].blank?

      spl = find_cached_parameter_instance(SpeciesList, :species_list)
      @title_tag = :query_title_in_species_list
      @title_args[:species_list] = spl.format_name
      where << "species_list_observations.species_list_id = '#{spl.id}'"
      add_join(:observations, :species_list_observations)
    end

    def add_where_conditions
      add_at_location_parameter(:observations)
      add_search_condition("observations.where", params[:user_where])
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
        params[:with_name]
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
