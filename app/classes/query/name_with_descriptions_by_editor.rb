class Query::NameWithDescriptionsByEditor < Query::Name
  def parameter_declarations
    user: User
  end

  def initialize_flavor
    type = "name"   # was: type = model_string.underscore
    glue = "editor" # was: glue = flavor.to_s.sub(/^.*_by_/, "")
    desc_table = :"#{type}_descriptions"
    glue_table = :"#{type}_descriptions_#{glue}s"
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(desc_table, glue_table)
    self.where << "#{glue_table}.user_id = '#{params[:user]}'"

    super
  end

  def default_order
    "name"
  end
end
