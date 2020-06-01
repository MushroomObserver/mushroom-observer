# frozen_string_literal: true

class Query::ArticlePatternSearch < Query::ArticleBase
  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    add_search_condition(search_fields, params[:pattern])
    super
  end

  def search_fields
    "CONCAT(" \
      "articles.title," \
      "COALESCE(articles.body,'')" \
      ")"
  end
end
