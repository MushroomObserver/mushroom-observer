module Query
  # Simple species list search.
  class SpeciesListPatternSearch < Query::SpeciesListBase
    include Query::Initializers::PatternSearch

    def parameter_declarations
      super.merge(
        pattern: :string
      )
    end

    def initialize_flavor
      search = google_parse_pattern
      add_search_conditions(search, *search_fields)
      add_join(:locations!)
      super
    end

    def search_fields
      [
        "species_lists.title",
        "COALESCE(species_lists.notes,'')",
        "IF(locations.id,locations.name,species_lists.where)"
      ]
    end
  end
end
