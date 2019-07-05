class Query::SpeciesListAtWhere < Query::SpeciesListBase
  def parameter_declarations
    super.merge(
      location:    :string,
      user_where?: :string # used to pass parameter to create_location
    )
  end

  def initialize_flavor
    title_args[:where] = params[:where]
    pattern = clean_pattern(params[:location])
    where << "species_lists.where LIKE '%#{pattern}%'"
    super
  end

  def default_order
    "name"
  end
end
