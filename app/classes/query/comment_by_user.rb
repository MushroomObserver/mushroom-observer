# frozen_string_literal: true

class Query::CommentByUser < Query::CommentBase
  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    where << "comments.user_id = '#{user.id}'"
    super
  end
end
