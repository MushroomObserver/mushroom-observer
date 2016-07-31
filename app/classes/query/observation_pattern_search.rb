class Query::ObservationPatternSearch < Query::Observation
  include Query::Initializers::PatternSearch

  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize
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
end
