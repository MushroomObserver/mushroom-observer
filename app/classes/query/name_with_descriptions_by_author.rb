class Query::NameWithDescriptionsByAuthor < Query::Name
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    type = "name"   # was: type = model_string.underscore
    glue = "author" # was: glue = flavor.to_s.sub(/^.*_by_/, "")
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
