class Query::NameWithDescriptionsByUser < Query::NameBase
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    desc_table = :name_descriptions
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(desc_table)
    self.where << "#{desc_table}.user_id = '#{user.id}'"
    super
  end

  def coerce_into_name_description_query
    Query.lookup(:NameDescription, :by_user, params)
  end
end
