class Query::ObservationAtWhere < Query::Observation
  def parameter_declarations
    super.merge(
      location: :string,
      user_where: :string
    )
  end

  def initialize_flavor
    title_args[:where] = params[:where]
    pattern = clean_pattern(params[:location])
    self.where << "locations.where LIKE '%#{pattern}%'"
    super
  end

  def default_order
    "name"
  end
end
