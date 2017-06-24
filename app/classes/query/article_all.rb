module Query
  # All articles
  class ArticleAll < Query::ArticleBase
    def initialize_flavor
      add_sort_order_to_title
      super
    end
  end
end
