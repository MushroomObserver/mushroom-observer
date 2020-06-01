# frozen_string_literal: true

class Query::CommentPatternSearch < Query::CommentBase
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
      "comments.summary," \
      "COALESCE(comments.comment,'')" \
      ")"
  end
end
