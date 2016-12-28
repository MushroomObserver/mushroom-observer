class Query::ObservationPatternSearch < Query::ObservationBase
  include Query::Initializers::PatternSearch

  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    search = google_parse_pattern
    add_search_conditions(search,
      "names.search_name",
      "COALESCE(observations.notes,'')",
      "IF(locations.id,locations.name,observations.where)"
    )
    add_join(:locations!)
    add_join(:names)
    super
  end

  def coerce_into_image_query
    Query.lookup(:Image, :with_observations_in_set, ids: result_ids)
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_observations_in_set, ids: result_ids)
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_observations_in_set, ids: result_ids)
  end
end
