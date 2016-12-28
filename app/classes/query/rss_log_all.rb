class Query::RssLogAll < Query::RssLogBase
  include Query::Initializers::All

  def initialize_flavor
    add_sort_order_to_title
    super
  end

  def coerce_into_location_query
    Query.lookup(:Location, :by_rss_log, params_minus_type)
  end

  def coerce_into_name_query
    Query.lookup(:Name, :by_rss_log, params_minus_type)
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :by_rss_log, params_minus_type)
  end

  def coerce_into_project_query
    Query.lookup(:Project, :by_rss_log, params_minus_type)
  end

  def coerce_into_species_list_query
    Query.lookup(:SpeciesList, :by_rss_log, params_minus_type)
  end

  def params_minus_type
    return params if !params.has_key(:type)
    params2 = params.dup
    params.delete(:type)
    params2
  end
end
