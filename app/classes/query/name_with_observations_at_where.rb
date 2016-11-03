class Query::NameWithObservationsAtWhere < Query::NameBase
  include Query::Initializers::ObservationFilters

  def parameter_declarations
    super.merge(
      location:   :string,
      user_where: :string  # apparently used only by observer controller(?)
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    location = params[:location]
    title_args[:where] = location
    add_join(:observations)
    self.where << "observations.where LIKE '%#{clean_pattern(location)}%'"
    self.where << "observations.is_collection_location IS TRUE"
    initialize_observation_filters
    super
  end
end
