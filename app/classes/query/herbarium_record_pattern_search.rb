module Query
  # Simple herbarium_record search.
  class HerbariumRecordPatternSearch < Query::HerbariumRecordBase
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
        "herbarium_records.initial_det",
        "herbarium_records.accession_number",
        "COALESCE(herbarium_records.notes,'')"
      ]
    end
  end
end
