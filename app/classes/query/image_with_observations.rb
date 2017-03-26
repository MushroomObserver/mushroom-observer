module Query
  # Images attached to observations.
  class ImageWithObservations < Query::ImageBase
    include Query::Initializers::ContentFilters

    def parameter_declarations
      super.merge(
        old_by?: :string
      ).merge(content_filter_parameter_declarations(Observation))
    end

    def initialize_flavor
      add_join(:images_observations, :observations)
      initialize_content_filters(Observation)
      super
    end

    def default_order
      "name"
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :all, params_with_old_by_restored)
    end
  end
end
