class Query::SpeciesListPatternSearch < Query::SpeciesListBase
  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    add_search_condition(search_fields, params[:pattern])
    add_join(:locations!)
    super
  end

  def search_fields
    "CONCAT(" \
      "species_lists.title," \
      "COALESCE(species_lists.notes,'')," \
      "IF(locations.id,locations.name,species_lists.where)" \
      ")"
  end
end
