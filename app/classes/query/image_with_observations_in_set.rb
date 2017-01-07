module Query
  # Images with observations in a given set.
  class ImageWithObservationsInSet < Query::ImageBase
    include Query::Initializers::ContentFilters

    def parameter_declarations
      super.merge(
        ids:        [Observation],
        old_title?: :string,
        old_by?:    :string
      ).merge(content_filter_parameter_declarations(Observation))
    end

    def initialize_flavor
      title_args[:observations] = params[:old_title] ||
                                  :query_title_in_set.t(type: :observation)
      set = clean_id_set(params[:ids])
      add_join(:images_observations, :observations)
      where << "observations.id IN (#{set})"
      initialize_content_filters(Observation)
      super
    end

    def default_order
      "name"
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :in_set, params_with_old_by_restored)
    end
  end
end
