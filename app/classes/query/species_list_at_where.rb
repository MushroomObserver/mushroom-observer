class Query::SpeciesListAtWhere < Query::SpeciesListBase
  def parameter_declarations
    super.merge(
      location: :string,
      user_where: :string  # apparently used only by observer controller(?)
    )
  end

  def initialize_flavor
    title_args[:where] = params[:where]
    pattern = clean_pattern(params[:location])
    self.where << "species_lists.where LIKE '%#{pattern}%'"
    super
  end

  def default_order
    "name"
  end
end
