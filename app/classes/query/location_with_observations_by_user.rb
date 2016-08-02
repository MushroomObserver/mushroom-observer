class Query::LocationWithObservationsByUser < Query::Location
  include Query::Initializers::ObservationFilters

  def parameter_declarations
    super.merge(
      user: User
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:observations)
    self.where << "observations.user_id = '#{user.id}'"
    self.where << "observations.is_collection_location IS TRUE"
    initialize_observation_filters
    super
  end
end
