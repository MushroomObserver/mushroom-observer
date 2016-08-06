class Query::ProjectPatternSearch < Query::ProjectBase
  include Query::Initializers::PatternSearch

  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    search = google_parse_pattern
    add_search_conditions(search,
      "projects.title",
      "COALESCE(projects.summary,'')",
    )
    super
  end
end
