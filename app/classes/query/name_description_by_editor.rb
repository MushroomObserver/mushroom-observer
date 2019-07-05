class Query::NameDescriptionByEditor < Query::NameDescriptionBase
  def parameter_declarations
    super.merge(
      user:    User,
      old_by?: :string
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:name_descriptions_editors)
    where << "name_descriptions_editors.user_id = '#{user.id}'"
    super
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_descriptions_by_editor, params_plus_old_by)
  end
end
