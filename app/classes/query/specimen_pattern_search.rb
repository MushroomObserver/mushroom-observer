module Query
  # Simple specimen search.
  class SpecimenPatternSearch < Query::SpecimenBase
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
        "specimens.herbarium_label",
        "COALESCE(specimens.notes,'')"
      ]
    end
  end
end
