class Query::CommentInSet < Query::Comment
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [Comment]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("comments")
    super
  end
end
