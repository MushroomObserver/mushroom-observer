class Query::NameDescriptionByAuthor < Query::NameDescription
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:name_descriptions_authors)
    self.where << "name_descriptions_authors.user_id = '#{user.id}'"
    super
  end
end
