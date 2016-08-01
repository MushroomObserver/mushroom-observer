class Query::LocationDescriptionByEditor < Query::LocationDescription
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name

    glue_table = "location_decriptions_editors".to_sym
    add_join(glue_table)
    self.where << "#{glue_table}.user_id = '#{params[:user]}'"
    super
  end

  def default_order
    "name"
  end
end
