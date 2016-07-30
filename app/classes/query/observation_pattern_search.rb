class Query::ObservationPatternSearch < Query::Observation
  include Query::PatternSearch

  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize
    search = google_parse_pattern
    add_join(:locations!)
    add_join(:names)
    add_search_conditions(search,
      "names.search_name",
      "COALESCE(observations.notes,'')",
      "IF(locations.id,locations.name,observations.where)"
    )
    super
  end
end
