class Query::SpeciesListInSet < Query::SpeciesList
  include Query::Initializers::InSet

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
