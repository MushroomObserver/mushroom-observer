class Query::NameByEditor < Query::Name
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name

    version_table = "names_versions".to_sym
    add_join(version_table)
    self.where << "#{version_table}.user_id = '#{params[:user]}'"
    self.where << "names.user_id != '#{params[:user]}'"
    super
  end

  def default_order
    super
  end
end
