module Query
  # Locations with observations of a given name.
  class LocationWithObservationsOfName < LocationWithObservations
    include Query::Initializers::ContentFilters
    include Query::Initializers::OfName

    def parameter_declarations
      super.merge(of_name_parameter_declarations)
    end

    def initialize_flavor
      give_parameter_defaults
      names = target_names
      choose_a_title(names, :with_observation)
      add_join(:observations)
      add_name_conditions(names)
      where << "observations.is_collection_location IS TRUE"
      initialize_content_filters(Observation)
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
