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
        projects?: [:string],
        species_lists?: [:string],
        herbaria?: [:string],
        confidence?: [:float],
        is_collection_location?: :boolean,
        has_location?: :boolean,
        has_name?: :boolean,
        has_comments?: { boolean: [true] },
        has_sequences?: { boolean: [true] },
        has_notes?: :boolean,
        has_notes_fields?: [:string],
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
      add_where_condition(:observations, params[:locations])
      initialize_association_parameters
      add_range_condition("observations.vote_cache", params[:confidence])
      initialize_boolean_parameters
      initialize_search_parameters
      initialize_content_filters(Observation)
      super
    end

    def initialize_association_parameters
      add_id_condition(
        "observations_projects.project_id",
        lookup_projects_by_name(params[:projects]),
        :observations, :observations_projects
      )
      add_id_condition(
        "observations_species_lists.species_list_id",
        lookup_species_lists_by_name(params[:species_lists]),
        :observations, :observations_species_lists
      )
      add_id_condition(
        "herbarium_records.herbarium_id",
        lookup_herbaria_by_name(params[:herbaria]),
        :observations, :herbarium_records_observations, :herbarium_records
      )
    end

    def initialize_boolean_parameters
      initialize_is_collection_location_parameter
      initialize_has_location_parameter
      initialize_has_name_parameter
      initialize_has_notes_parameter
      add_has_notes_fields_condition(params[:has_notes_fields])
      add_join(:observations, :comments) if params[:has_comments]
      add_join(:observations, :sequences) if params[:has_sequences]
    end

    def initialize_is_collection_location_parameter
      add_boolean_condition(
        "observations.is_collection_location IS TRUE",
        "observations.is_collection_location IS FALSE",
        params[:is_collection_location]
      )
    end

    def initialize_has_location_parameter
      add_boolean_condition(
        "observations.location_id IS NOT NULL",
        "observations.location_id IS NULL",
        params[:has_location]
      )
    end

    def initialize_has_name_parameter
      genus = Name.ranks[:Genus]
      group = Name.ranks[:Group]
      add_boolean_condition(
        "names.`rank` <= #{genus} or names.`rank` = #{group}",
        "names.`rank` > #{genus} and names.`rank` < #{group}",
        params[:has_name],
        :observations, :names
      )
    end

    def initialize_has_notes_parameter
      add_boolean_condition(
        "observations.notes != #{escape(Observation.no_notes_persisted)}",
        "observations.notes  = #{escape(Observation.no_notes_persisted)}",
        params[:has_notes]
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
