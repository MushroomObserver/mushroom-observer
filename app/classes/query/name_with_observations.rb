# frozen_string_literal: true

module Query
  # Query's for Names where Observations meet specified conditions
  class NameWithObservations < Query::NameBase
    include Query::Initializers::Names
    include Query::Initializers::Observations
    include Query::Initializers::Locations
    include Query::Initializers::ContentFilters
    include Query::Initializers::ObservationQueryDescriptions

    def parameter_declarations
      super.merge(observations_parameter_declarations).
        merge(observations_coercion_parameter_declarations).
        merge(bounding_box_parameter_declarations).
        merge(content_filter_parameter_declarations(Observation)).
        merge(naming_consensus_parameter_declarations)
    end

    def initialize_flavor
      add_join(:observations)
      initialize_obs_basic_parameters
      initialize_obs_association_parameters
      initialize_obs_record_parameters
      initialize_obs_search_parameters
      initialize_name_parameters(:observations)
      add_bounding_box_conditions_for_observations
      initialize_content_filters(Observation)
      super
    end

    def initialize_obs_association_parameters
      add_at_location_condition(:observations)
      project_joins = [:observations, :project_observations]
      initialize_projects_parameter(:project_observations, project_joins)
      add_for_project_condition(:project_observations, project_joins)
      add_in_species_list_condition
      initialize_herbaria_parameter
    end

    def title
      default = super
      with_observations_query_description || default
    end
  end
end
