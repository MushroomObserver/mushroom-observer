class Query::SpeciesListInSet < Query::SpeciesListBase
  def parameter_declarations
    super.merge(
      ids: [SpeciesList]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end
