module Query
  # Names with observations at a given location.
  class NameWithObservationsAtLocation < NameWithObservations
    include Query::Initializers::ContentFilters

    def parameter_declarations
      super.merge(
        location: Location
      )
    end

    def initialize_flavor
      location = find_cached_parameter_instance(Location, :location)
      title_args[:location] = location.display_name
      add_join(:observations)
      where << "observations.location_id = '#{params[:location]}'"
      where << "observations.is_collection_location IS TRUE"
      initialize_content_filters(Observation)
      super
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :at_location, params_with_old_by_restored)
    end
  end
end
