class Query::CommentForUser < Query::CommentBase
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:observations)
    where << "observations.user_id = '#{params[:user]}'"
    super
  end
end
