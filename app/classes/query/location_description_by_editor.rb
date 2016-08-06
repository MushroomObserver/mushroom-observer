class Query::LocationDescriptionByEditor < Query::LocationDescriptionBase
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:location_descriptions_editors)
    self.where << "location_descriptions_editors.user_id = '#{user.id}'"
    super
  end
end
