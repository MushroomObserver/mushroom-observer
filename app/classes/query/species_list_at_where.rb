class Query::SpeciesListAtWhere < Query::SpeciesList
  def parameter_declarations
    super.merge(
      location: :string,
      user_where: :string
    )
  end

  def initialize
    title_args[:where] = params[:where]
    pattern = clean_pattern(params[:location])
    self.where << "species_lists.where LIKE '%#{pattern}%'"
    params[:by] ||= "name"
    super
  end
end
