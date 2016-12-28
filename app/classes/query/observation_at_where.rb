class Query::ObservationAtWhere < Query::ObservationBase
  def parameter_declarations
    super.merge(
      location: :string,
      user_where: :string  # apparently used only by observer controller(?)
    )
  end

  def initialize_flavor
    title_args[:where] = params[:where]
    pattern = clean_pattern(params[:location])
    self.where << "observations.where LIKE '%#{pattern}%'"
    super
  end

  def default_order
    "name"
  end

  def coerce_into_image_query
    Query.lookup(:Image, :with_observations_at_where, params)
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_observations_at_where, params)
  end
end
