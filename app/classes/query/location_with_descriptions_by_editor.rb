class Query::LocationWithDescriptionsByEditor < Query::LocationBase
  def parameter_declarations
    super.merge(
      user:    User,
      old_by?: :string
    )
  end

  def initialize_flavor
    desc_table = :location_descriptions
    glue_table = :location_descriptions_editors
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(desc_table, glue_table)
    self.where << "#{glue_table}.user_id = '#{user.id}'"
    super
  end

  def coerce_into_location_description_query
    Query.lookup(:LocationDescription, :by_editor, params_with_old_by_restored)
  end
end
