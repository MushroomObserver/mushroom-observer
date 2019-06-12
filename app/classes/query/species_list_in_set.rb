class Query::SpeciesListInSet < Query::SpeciesListBase
  def parameter_declarations
    super.merge(
      ids: [SpeciesList]
    )
  end

  def initialize_flavor
    add_id_condition("species_lists.id", params[:ids])
    super
  end
end
