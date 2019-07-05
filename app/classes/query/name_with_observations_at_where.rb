class Query::NameWithObservationsAtWhere < Query::NameWithObservations
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      location:    :string,
      user_where?: :string # used to pass parameter to create_location
    )
  end

  def initialize_flavor
    location = params[:location]
    title_args[:where] = location
    where << "observations.where LIKE '%#{clean_pattern(location)}%'"
    where << "observations.is_collection_location IS TRUE"
    super
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :at_where, params_with_old_by_restored)
  end
end
