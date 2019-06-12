class Query::CommentInSet < Query::CommentBase
  def parameter_declarations
    super.merge(
      ids: [Comment]
    )
  end

  def initialize_flavor
    add_id_condition("comments.id", params[:ids])
    super
  end
end
