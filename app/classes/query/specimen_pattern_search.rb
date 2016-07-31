class Query::SpecimenPatternSearch < Query::Specimen
  include Query::PatternSearch

  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize
    search = google_parse_pattern
    add_search_conditions(search,
      "specimens.herbarium_label",
      "COALESCE(specimens.notes,'')"
    )
  super
  end
end
