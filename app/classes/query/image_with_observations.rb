# frozen_string_literal: true

module Query
  # Query's for Images where Observation meets specified conditions
  class ImageWithObservations < Query::ImageBase
    include Query::Initializers::Names
    include Query::Initializers::Observations
    include Query::Initializers::Locations
    include Query::Initializers::ContentFilters
    include Query::Initializers::ObservationQueryDescriptions

    def parameter_declarations
      super.merge(
        obs_ids?: [Observation]
      ).merge(observations_parameter_declarations).
        merge(observations_coercion_parameter_declarations).
        merge(bounding_box_parameter_declarations).
        merge(content_filter_parameter_declarations(Observation)).
        merge(naming_consensus_parameter_declarations)
    end

    def initialize_flavor
      add_join(:observation_images, :observations)
      add_ids_condition("observations", :obs_ids)
      add_owner_and_time_stamp_conditions("observations")
      add_by_user_condition("observations")
      add_date_condition("observations.when", params[:date])
      initialize_association_parameters
      add_where_conditions
      initialize_boolean_parameters
      initialize_obs_search_parameters
      add_bounding_box_conditions_for_observations
      initialize_content_filters(Observation)
      super
    end

    def initialize_association_parameters
      initialize_herbaria_parameter
      initialize_projects_parameter(:project_observations)
      add_for_project_condition(:project_observations,
                                [:observations, :project_observations])
      add_in_species_list_condition
    end

    def add_where_conditions
      add_at_location_condition(:observations)
      add_search_condition("observations.where", params[:user_where])
    end

    def initialize_boolean_parameters
      initialize_is_collection_location_parameter
      initialize_with_public_lat_lng_parameter
      initialize_with_name_parameter
      initialize_with_obs_notes_parameter
      add_join(:observations, :comments) if params[:with_comments]
      add_join(:observations, :sequences) if params[:with_sequences]
      add_with_notes_fields_condition(params[:with_notes_fields])
    end

    def default_order
      "name"
    end

    def title
      default = super
      with_observations_query_description || default
    end
  end
end
