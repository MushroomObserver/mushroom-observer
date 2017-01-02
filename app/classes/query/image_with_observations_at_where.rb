module Query
  # Images with observations at a given "where".
  class ImageWithObservationsAtWhere < Query::ImageBase
    include Query::Initializers::ObservationFilters

    def parameter_declarations
      super.merge(
        location:    :string,
        user_where?: :string, # used to pass parameter to create_location
        old_by?:     :string
      ).merge(observation_filter_parameter_declarations)
    end

    def initialize_flavor
      location = params[:location]
      title_args[:where] = location
      add_join(:images_observations, :observations)
      where << "observations.where LIKE '%#{clean_pattern(location)}%'"
      where << "observations.is_collection_location IS TRUE"
      initialize_observation_filters
      super
    end

    def default_order
      "name"
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :at_where, params_with_old_by_restored)
    end
  end
end
