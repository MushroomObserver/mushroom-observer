class Query::NameWithDescriptionsByEditor < Query::NameBase
  def parameter_declarations
    super.merge(
      user: User,
      old_by?: :string
    )
  end

  def initialize_flavor
    glue_table = :name_descriptions_editors
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:name_descriptions, glue_table)
    where << "#{glue_table}.user_id = '#{user.id}'"
    super
  end

  def coerce_into_name_description_query
    Query.lookup(:NameDescription, :by_editor, params_with_old_by_restored)
  end
end
