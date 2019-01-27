module Query
  # All rss logs.
  class RssLogAll < Query::RssLogBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end

    def coerce_into_article_query
      do_coerce(:Article)
    end

    def coerce_into_location_query
      do_coerce(:Location)
    end

    def coerce_into_name_query
      do_coerce(:Name)
    end

    def coerce_into_observation_query
      do_coerce(:Observation)
    end

    def coerce_into_project_query
      do_coerce(:Project)
    end

    def coerce_into_species_list_query
      do_coerce(:SpeciesList)
    end

    def do_coerce(new_model)
      Query.lookup(new_model, :by_rss_log, params_minus_type)
    end

    def params_minus_type
      return params unless params.key?(:type)

      params2 = params.dup
      params2.delete(:type)
      params2
    end
  end
end
