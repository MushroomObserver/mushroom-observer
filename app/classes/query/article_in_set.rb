class Query::ArticleInSet < Query::ArticleBase
  def parameter_declarations
    super.merge(
      ids: [Article]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end
