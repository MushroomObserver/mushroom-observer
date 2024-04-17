# frozen_string_literal: true

module Query
  # methods for initializing Query's for Observations
  class ObservationBase < Query::Base
    include Query::Initializers::ContentFilters
    include Query::Initializers::Names

    def model
      Observation
    end

    def parameter_declarations
      super.merge(
        # dates/times
        date?: [:date],
        created_at?: [:time],
        updated_at?: [:time],

        comments_has?: :string,
        with_notes_fields?: [:string],
        herbaria?: [:string],
        herbarium_records?: [:string],
        locations?: [:string],
        notes_has?: :string,
        projects?: [:string],
        project_lists?: [:string],
        species_lists?: [:string],
        users?: [User],

        # numeric
        confidence?: [:float],
        east?: :float,
        north?: :float,
        south?: :float,
        west?: :float,

        # boolean
        with_comments?: { boolean: [true] },
        with_public_lat_lng?: :boolean,
        with_name?: :boolean,
        with_notes?: :boolean,
        with_sequences?: { boolean: [true] },
        is_collection_location?: :boolean
      ).merge(content_filter_parameter_declarations(Observation)).
        merge(names_parameter_declarations).
        merge(consensus_parameter_declarations)
    end

    def initialize_flavor
      add_owner_and_time_stamp_conditions("observations")
      add_date_condition("observations.when", params[:date])
      initialize_name_parameters
      initialize_association_parameters
      initialize_boolean_parameters
      initialize_search_parameters
      add_range_condition("observations.vote_cache", params[:confidence])
      add_bounding_box_conditions_for_observations
      initialize_content_filters(Observation)
      super
    end

    def initialize_association_parameters
      add_where_condition("observations", params[:locations])
      initialize_herbaria_parameter
      initialize_herbarium_records_parameter
      initialize_projects_parameter
      initialize_project_lists_parameter
      initialize_species_lists_parameter
    end

    def initialize_herbaria_parameter
      add_id_condition(
        "herbarium_records.herbarium_id",
        lookup_herbaria_by_name(params[:herbaria]),
        :observation_herbarium_records, :herbarium_records
      )
    end

    def initialize_herbarium_records_parameter
      add_id_condition(
        "observation_herbarium_records.herbarium_record_id",
        lookup_herbarium_records_by_name(params[:herbarium_records]),
        :observation_herbarium_records
      )
    end

    def initialize_projects_parameter
      add_id_condition(
        "project_observations.project_id",
        lookup_projects_by_name(params[:projects]),
        :project_observations
      )
    end

    def initialize_project_lists_parameter
      add_id_condition(
        "species_list_observations.species_list_id",
        lookup_lists_for_projects_by_name(params[:project_lists]),
        :species_list_observations
      )
    end

    def initialize_species_lists_parameter
      add_id_condition(
        "species_list_observations.species_list_id",
        lookup_species_lists_by_name(params[:species_lists]),
        :species_list_observations
      )
    end

    def initialize_boolean_parameters
      initialize_is_collection_location_parameter
      initialize_with_public_lat_lng_parameter
      initialize_with_name_parameter
      initialize_with_notes_parameter
      add_with_notes_fields_condition(params[:with_notes_fields])
      add_join(:comments) if params[:with_comments]
      add_join(:sequences) if params[:with_sequences]
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
        :names
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
        :comments
      )
    end

    def add_join_to_locations!
      add_join(:locations!)
    end

    def self.default_order
      "date"
    end
  end
end
