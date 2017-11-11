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
        # I'm leaving out bases because it would be misleading.  Some formats allow
        # spaces and other delimiting "garbage" which could break up the subsequence
        # the user is searching for.
        "COALESCE(sequences.locus,'')",
        "COALESCE(sequences.archive,'')",
        "COALESCE(sequences.accession,'')",
        "COALESCE(sequences.notes,'')"
      ]
    end
  end
end
