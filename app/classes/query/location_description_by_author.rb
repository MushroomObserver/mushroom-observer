class Query::LocationDescriptionByAuthor < Query::LocationDescriptionBase
  def parameter_declarations
    super.merge(
      user:    User,
      old_by?: :string
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:location_descriptions_authors)
    where << "location_descriptions_authors.user_id = '#{user.id}'"
    super
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_descriptions_by_author, params_plus_old_by)
  end
end
