module Query
  # Locations with observations of subtaxa of a given name.
  class LocationWithObservationsOfChildren < LocationWithObservations
    include Query::Initializers::ContentFilters
    include Query::Initializers::OfChildren

    def parameter_declarations
      super.merge(
        name: Name,
        all?: :boolean
      )
    end

    def initialize_flavor
      name = find_cached_parameter_instance(Name, :name)
      title_args[:name] = name.display_name
      add_name_condition(name)
      add_join(:observations)
      add_join(:observations, :names)
      initialize_content_filters(Observation)
      super
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :of_children, params_with_old_by_restored)
    end
  end
end
