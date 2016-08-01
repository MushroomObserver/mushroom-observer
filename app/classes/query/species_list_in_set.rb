class Query::SpeciesListInSet < Query::SpeciesList
  def parameter_declarations
    super.merge(
      ids: [SpeciesList]
    )
  end

  def initialize_flavor
    table = "species_lists"
    set = clean_id_set(params[:ids])
    self.where << "#{table}.id IN (#{set})"
    self.order = "FIND_IN_SET(#{table}.id,'#{set}') ASC"
    super
  end
end
