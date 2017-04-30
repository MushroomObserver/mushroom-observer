module Query
  # Articles in a given set.
  class ArticleInSet < Query::ArticleBase
    def parameter_declarations
      super.merge(
        ids: [Article]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("articles")
      super
    end
  end
end
