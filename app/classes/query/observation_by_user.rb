class Query::ObservationByUser < Query::ObservationBase
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.where << "observations.user_id = '#{user.id}'"
    super
  end

  def default_order
    "updated_at"
  end

  def coerce_into_image_query
    Query.lookup(:Image, :with_observations_by_user, params)
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_observations_by_user, params)
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_observations_by_user, params)
  end
end
