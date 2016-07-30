class Query::ObservationAtWhere < Query::Observation
  def self.parameter_declarations
    super.merge(
      location: :string,
      user_where: :string
    )
  end

  def initialize
    title_args[:where] = params[:where]
    pattern = clean_pattern(params[:location])
    add_join(:names)
    self.where << "locations.where LIKE '%#{pattern}%'"
    params[:by] ||= "name"
  end
end
