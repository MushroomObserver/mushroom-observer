module Query
  # Simple Sequence search.
  class SequencePatternSearch < Query::SequenceBase
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
        "sequences.title",
        "COALESCE(sequences.body,'')"
      ]
    end
  end
end
