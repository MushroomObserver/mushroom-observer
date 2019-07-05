class Query::CommentInSet < Query::CommentBase
  def parameter_declarations
    super.merge(
      ids: [Comment]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end
