class Query::NameWithObservationsByUser < Query::Name
  def parameter_declarations
    super.merge(
      user: User,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:observations)
    self.where << "observations.user_id = '#{params[:user]}'"
    initialize_observation_filters

    super
  end

  def default_order
    "name"
  end
end
