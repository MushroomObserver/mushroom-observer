# frozen_string_literal: true

module Query
  # Methods to validate parameters and initialize Query's which return Sequences
  class SequenceBase < Query::Base
    include Query::Initializers::Names

    def model
      Sequence
    end

    def parameter_declarations
      super.merge(sequence_parameter_declarations).
        merge(observation_parameter_declarations).
        merge(names_parameter_declarations)
    end

    def sequence_parameter_declarations
      {
        created_at?: [:time],
        updated_at?: [:time],
        observations?: [Observation],
        users?: [User],
        locus?: [:string],
        archive?: [:string],
        accession?: [:string],
        locus_has?: :string,
        accession_has?: :string,
        notes_has?: :string
      }
    end

    def observation_parameter_declarations
      {
        obs_date?: [:date],
        observers?: [User],
        locations?: [:string],
        herbaria?: [:string],
        herbarium_records?: [:string],
        projects?: [:string],
        species_lists?: [:string],
        confidence?: [:float],
        north?: :float,
        south?: :float,
        east?: :float,
        west?: :float,
        is_collection_location?: :boolean,
        has_images?: :boolean,
        has_name?: :boolean,
        has_specimen?: :boolean,
        has_obs_notes?: :boolean,
        has_notes_fields?: [:string],
        obs_notes_has?: :string
      }
    end

    def initialize_flavor
      # Leaving out bases because some formats allow spaces and other "garbage"
      # delimiters which could interrupt the subsequence the user is searching
      # for.  Users would probably not understand why the search fails to find
      # some sequences because of this.
      add_owner_and_time_stamp_conditions("sequences")
      initialize_association_parameters
      initialize_name_parameters(:observations)
      initialize_observation_parameters
      initialize_exact_match_parameters
      initialize_boolean_parameters
      initialize_search_parameters
      add_bounding_box_conditions_for_observations
      super
    end

    def initialize_association_parameters
      add_id_condition("sequences.observation_id", params[:observations])
      initialize_observers_parameter
      initialize_locations_parameter
      initialize_herbaria_parameter
      initialize_herbarium_records_parameter
      initialize_projects_parameter
      initialize_species_lists_parameter
    end

    def initialize_observers_parameter
      add_id_condition(
        "observations.user_id",
        lookup_users_by_name(params[:observers]),
        :observations
      )
    end

    def initialize_locations_parameter
      add_id_condition(
        "observations.location_id",
        lookup_locations_by_name(params[:locations]),
        :observations
      )
    end

    def initialize_herbaria_parameter
      add_id_condition(
        "herbarium_records.herbarium_id",
        lookup_herbaria_by_name(params[:herbaria]),
        :observations, :observation_herbarium_records, :herbarium_records
      )
    end

    def initialize_herbarium_records_parameter
      add_id_condition(
        "observation_herbarium_records.herbarium_record_id",
        lookup_herbarium_records_by_name(params[:herbarium_records]),
        :observations, :observation_herbarium_records
      )
    end

    def initialize_projects_parameter
      add_id_condition(
        "project_observations.project_id",
        lookup_projects_by_name(params[:projects]),
        :observations, :project_observations
      )
    end

    def initialize_species_lists_parameter
      add_id_condition(
        "species_list_observations.species_list_id",
        lookup_species_lists_by_name(params[:species_lists]),
        :observations, :species_list_observations
      )
    end

    def initialize_observation_parameters
      add_date_condition(
        "observations.when",
        params[:obs_date],
        :observations
      )
      add_boolean_condition(
        "observations.is_collection_location IS TRUE",
        "observations.is_collection_location IS FALSE",
        params[:is_collection_location],
        :observations
      )
      add_range_condition(
        "observations.vote_cache",
        params[:confidence],
        :observations
      )
    end

    def initialize_exact_match_parameters
      add_exact_match_condition("sequences.locus", params[:locus])
      add_exact_match_condition("sequences.archive", params[:archive])
      add_exact_match_condition("sequences.accession", params[:accession])
    end

    def initialize_boolean_parameters
      initialize_has_images_parameter
      initialize_has_specimen_parameter
      initialize_has_name_parameter
      initialize_has_obs_notes_parameter
      add_has_notes_fields_condition(params[:has_notes_fields], :observations)
    end

    def initialize_has_images_parameter
      add_boolean_condition(
        "observations.thumb_image_id IS NOT NULL",
        "observations.thumb_image_id IS NULL",
        params[:has_images],
        :observations
      )
    end

    def initialize_has_specimen_parameter
      add_boolean_condition(
        "observations.specimen IS TRUE",
        "observations.specimen IS FALSE",
        params[:has_specimen],
        :observations
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

    def initialize_has_obs_notes_parameter
      add_boolean_condition(
        "observations.notes != #{escape(Observation.no_notes_persisted)}",
        "observations.notes  = #{escape(Observation.no_notes_persisted)}",
        params[:has_obs_notes],
        :observations
      )
    end

    def initialize_search_parameters
      add_search_condition("sequences.locus", params[:locus_has])
      add_search_condition("sequences.accession", params[:accession_has])
      add_search_condition("sequences.notes", params[:notes_has])
      add_search_condition("observations.notes", params[:obs_notes_has],
                           :observations)
    end

    def add_join_to_locations!
      add_join(:observations, :locations!)
    end

    def self.default_order
      "created_at"
    end
  end
end
