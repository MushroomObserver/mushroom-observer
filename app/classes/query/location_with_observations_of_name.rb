module Query
  # Locations with observations of a given name.
  class LocationWithObservationsOfName < Query::LocationBase
    include Query::Initializers::ObservationFilters
    include Query::Initializers::OfName

    def parameter_declarations
      super.merge(
        old_by?: :string
      ).merge(of_name_parameter_declarations).
        merge(observation_filter_parameter_declarations)
    end

    def initialize_flavor
      give_parameter_defaults
      names = target_names
      choose_a_title(names, :with_observation)
      add_join(:observations)
      add_name_conditions(names)
      where << "observations.is_collection_location IS TRUE"
      initialize_observation_filters
      super
    end

    def add_join_to_observations(table)
      add_join(:observations, table)
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :of_name, params_with_old_by_restored)
    end
  end
end
