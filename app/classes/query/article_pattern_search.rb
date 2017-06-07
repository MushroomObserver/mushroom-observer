module Query
  # Simple Article search.
  class ArticlePatternSearch < Query::ArticleBase
    include Query::Initializers::PatternSearch

    def parameter_declarations
      super.merge(
        pattern: :string
      )
    end

    def initialize_flavor
      search = google_parse_pattern
      add_search_conditions(search, *search_fields)
      super
    end

    def search_fields
      [
        "articles.title",
        "COALESCE(articles.body,'')"
      ]
    end
  end
end
