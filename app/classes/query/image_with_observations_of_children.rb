module Query
  # Images with observations of subtaxa of a given name.
  class ImageWithObservationsOfChildren < Query::ImageBase
    include Query::Initializers::ContentFilters
    include Query::Initializers::OfChildren

    def parameter_declarations
      super.merge(
        name:    Name,
        all?:    :boolean,
        old_by?: :string
      ).merge(content_filter_parameter_declarations(Observation))
    end

    def initialize_flavor
      name = find_cached_parameter_instance(Name, :name)
      title_args[:name] = name.display_name
      add_name_condition(name)
      add_join(:images_observations, :observations)
      add_join(:observations, :names)
      initialize_content_filters(Observation)
      super
    end

    def default_order
      "name"
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :of_children, params_with_old_by_restored)
    end
  end
end
