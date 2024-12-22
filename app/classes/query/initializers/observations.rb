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

      def initialize_obs_date_parameter(param_name = :date)
        add_date_condition(
          "observations.when",
          params[param_name],
          :observations
        )
      end

      def initialize_project_lists_parameter
        add_id_condition(
          "species_list_observations.species_list_id",
          lookup_lists_for_projects_by_name(params[:project_lists]),
          :observations, :species_list_observations
        )
      end

      def initialize_field_slips_parameter
        return unless params[:field_slips]

        add_join(:field_slips)
        add_exact_match_condition(
          "field_slips.code",
          params[:field_slips],
          :observations
        )
      end

      def initialize_obs_record_parameters
        initialize_obs_is_collection_location_parameter
        initialize_obs_with_public_lat_lng_parameter
        initialize_obs_with_name_parameter
        initialize_obs_naming_confidence_parameter
        initialize_obs_with_notes_parameter
        add_with_notes_fields_condition(params[:with_notes_fields])
        add_join(:observations, :comments) if params[:with_comments]
        add_join(:observations, :sequences) if params[:with_sequences]
      end

      def initialize_obs_is_collection_location_parameter
        add_boolean_condition(
          "observations.is_collection_location IS TRUE",
          "observations.is_collection_location IS FALSE",
          params[:is_collection_location],
          :observations
        )
      end

      def initialize_obs_with_public_lat_lng_parameter
        add_boolean_condition(
          "observations.lat IS NOT NULL AND observations.gps_hidden IS FALSE",
          "observations.lat IS NULL OR observations.gps_hidden IS TRUE",
          params[:with_public_lat_lng],
          :observations
        )
      end

      def initialize_obs_with_images_parameter
        add_boolean_condition(
          "observations.thumb_image_id IS NOT NULL",
          "observations.thumb_image_id IS NULL",
          params[:with_images],
          :observations
        )
      end

      def initialize_obs_with_specimen_parameter
        add_boolean_condition(
          "observations.specimen IS TRUE",
          "observations.specimen IS FALSE",
          params[:with_specimen],
          :observations
        )
      end

      def initialize_obs_with_name_parameter
        genus = Name.ranks[:Genus]
        group = Name.ranks[:Group]
        add_boolean_condition(
          "names.`rank` <= #{genus} or names.`rank` = #{group}",
          "names.`rank` > #{genus} and names.`rank` < #{group}",
          params[:with_name],
          :observations, :names
        )
      end

      def initialize_obs_naming_confidence_parameter
        add_range_condition(
          "observations.vote_cache",
          params[:confidence],
          :observations
        )
      end

      def initialize_obs_with_notes_parameter(param_name = :with_notes)
        add_boolean_condition(
          "observations.notes != #{escape(Observation.no_notes_persisted)}",
          "observations.notes  = #{escape(Observation.no_notes_persisted)}",
          params[param_name],
          :observations
        )
      end

      def initialize_obs_search_parameters
        add_search_condition("observations.notes", params[:notes_has])
        add_search_condition(
          "CONCAT(comments.summary,COALESCE(comments.comment,''))",
          params[:comments_has], :observations, :comments
        )
        add_search_condition("observations.where", params[:user_where])
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
