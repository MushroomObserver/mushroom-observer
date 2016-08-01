class Query::NameWithDescriptionsByUser < Query::Name
  def parameter_declarations
    user: User
  end

  def initialize_flavor
    type = "name"   # was: type = model_string.underscore
    desc_table = :"#{type}_descriptions"
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(desc_table)
    self.where << "#{desc_table}.user_id = '#{params[:user]}'"

    super
  end

  def default_order
    "name"
  end
end
