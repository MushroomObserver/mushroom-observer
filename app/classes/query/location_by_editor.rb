class Query::LocationByEditor < Query::LocationBase
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    version_table = :locations_versions
    add_join(version_table)
    where << "#{version_table}.user_id = '#{user.id}'"
    where << "locations.user_id != '#{user.id}'"
    super
  end

  def default_order
    super
  end
end
