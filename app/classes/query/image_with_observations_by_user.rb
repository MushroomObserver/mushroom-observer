class Query::ImageWithObservationsByUser < Query::Image
  include Query::Initializers::ObservationFilters

  def parameter_declarations
    super.merge(
      user: User
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:images_observations, :observations)
    self.where << "observations.user_id = '#{params[:user]}'"
    initialize_observation_filters
    super
  end

  def default_order
    "name"
  end
end
