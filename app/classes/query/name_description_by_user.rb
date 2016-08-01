class Query::NameDescriptionByUser < Query::NameDescription
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.where << "name_descriptions.user_id = '#{user.id}'"
    super
  end

  def default_order
    "name"
  end
end
