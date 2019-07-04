class Query::ImageByUser < Query::ImageBase
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    where << "images.user_id = '#{user.id}'"
    super
  end

  def default_order
    "updated_at"
  end
end
