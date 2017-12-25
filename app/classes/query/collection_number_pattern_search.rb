module Query
  # Simple collection_number search.
  class CollectionNumberPatternSearch < Query::CollectionNumberBase
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
        "collection_numbers.name",
        "collection_numbers.number"
      ]
    end
  end
end
