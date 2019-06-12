class Query::ArticleInSet < Query::ArticleBase
  def parameter_declarations
    super.merge(
      ids: [Article]
    )
  end

  def initialize_flavor
    add_id_condition("articles.id", params[:ids])
    super
  end
end
