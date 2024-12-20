# frozen_string_literal: true

module Query
  module Initializers
    # initializing methods inherited by all Query's for Observations
    module Observations
      def observations_parameter_declarations
        {
          notes_has?: :string,
          with_notes_fields?: [:string],
          comments_has?: :string,
          herbaria?: [:string],
          user_where?: :string,
          by_user?: User,
          location?: Location,
          locations?: [:string],
          project?: Project,
          projects?: [:string],
          species_list?: SpeciesList,
          species_lists?: [:string],

          # boolean
          with_comments?: { boolean: [true] },
          with_public_lat_lng?: :boolean,
          with_name?: :boolean,
          with_notes?: :boolean,
          with_sequences?: { boolean: [true] },
          is_collection_location?: :boolean,

          # numeric
          confidence?: [:float]
        }
      end

      def observations_coercion_parameter_declarations
        {
          old_title?: :string,
          old_by?: :string,
          date?: [:date]
        }
      end

      # This is just to allow the additional location conditions
      def add_ids_condition(table = model.table_name, ids = :ids)
        return if params[ids].nil? # [] is valid

        super
        add_is_collection_location_condition_for_locations
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
        project_joins = [:observations, :project_observations]
        project_joins << :observation_images if model == Image

        add_id_condition(
          "project_observations.project_id",
          lookup_projects_by_name(params[:projects]),
          *project_joins
        )
      end

      def initialize_project_lists_parameter
        add_id_condition(
          "species_list_observations.species_list_id",
          lookup_lists_for_projects_by_name(params[:project_lists]),
          :observations, :species_list_observations
        )
      end

      def initialize_species_lists_parameter
        add_id_condition(
          "species_list_observations.species_list_id",
          lookup_species_lists_by_name(params[:species_lists]),
          :observations, :species_list_observations
        )
      end

      def add_in_species_list_condition
        return if params[:species_list].blank?

        spl = find_cached_parameter_instance(SpeciesList, :species_list)
        @title_tag = :query_title_in_species_list
        @title_args[:species_list] = spl.format_name
        where << "species_list_observations.species_list_id = '#{spl.id}'"
        add_is_collection_location_condition_for_locations
        add_join(:observations, :species_list_observations)
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

      def params_out_to_with_observations_params(pargs)
        return pargs if pargs[:ids].blank?

        pargs[:obs_ids] = pargs.delete(:ids)
        pargs
      end

      def params_back_to_observation_params
        pargs = params_with_old_by_restored
        return pargs if pargs[:obs_ids].blank?

        pargs[:ids] = pargs.delete(:obs_ids)
        pargs
      end

      def coerce_into_observation_query
        Query.lookup(:Observation, :all, params_back_to_observation_params)
      end
    end
  end
end
