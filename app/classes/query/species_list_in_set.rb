module Query
  # Species lists in a given set.
  class SpeciesListInSet < Query::SpeciesListBase
    def parameter_declarations
      super.merge(
        ids: [SpeciesList]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("species_lists")
      super
    end
  end
end
