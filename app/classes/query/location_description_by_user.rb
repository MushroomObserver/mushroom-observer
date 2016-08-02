class Query::LocationDescriptionByUser < Query::LocationDescription
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.where << "location_descriptions.user_id = '#{user.id}'"
    super
  end
end
