class Query::NameWithDescriptionsByAuthor < Query::Name
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    desc_table = :name_descriptions
    glue_table = :name_descriptions_authors
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(desc_table, glue_table)
    self.where << "#{glue_table}.user_id = '#{user.id}'"
    super
  end
end
