module Query
  # Images with observations at a given location.
  class ImageWithObservationsAtLocation < Query::ImageBase
    include Query::Initializers::ContentFilters

    def parameter_declarations
      super.merge(
        location: Location,
        old_by?:  :string
      ).merge(content_filter_parameter_declarations(Observation))
    end

    def initialize_flavor
      location = find_cached_parameter_instance(Location, :location)
      title_args[:location] = location.display_name
      add_join(:images_observations, :observations)
      where << "observations.location_id = '#{params[:location]}'"
      where << "observations.is_collection_location IS TRUE"
      initialize_content_filters(Observation)
      super
    end

    def default_order
      "name"
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :at_location, params_with_old_by_restored)
    end
  end
end
