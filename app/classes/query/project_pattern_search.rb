module Query
  # Simple project search.
  class ProjectPatternSearch < Query::ProjectBase
    include Query::Initializers::PatternSearch

    def parameter_declarations
      super.merge(
        pattern: :string
      )
    end

    def initialize_flavor
      search = google_parse_pattern
      add_search_conditions(search, *search_fields)
      super
    end

    def search_fields
      [
        "projects.title",
        "COALESCE(projects.summary,'')"
      ]
    end
  end
end
