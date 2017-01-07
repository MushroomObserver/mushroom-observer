module Query
  # Locations with observations.
  class LocationWithObservations < Query::LocationBase
    include Query::Initializers::ContentFilters

    def parameter_declarations
      super.merge(
        old_by?: :string
      ).merge(content_filter_parameter_declarations(Observation))
    end

    def initialize_flavor
      add_join(:observations)
      initialize_content_filters(Observation)
      super
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :all, params_with_old_by_restored)
    end
  end
end
