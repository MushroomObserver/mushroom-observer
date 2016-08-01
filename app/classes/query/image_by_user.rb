class Query::ImageByUser < Query::Image
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    self.where << "images.user_id = '#{user.id}'"
    super
  end

  def default_order
    "updated_at"
  end
end
