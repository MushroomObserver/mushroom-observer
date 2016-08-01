class Query::CommentPatternSearch < Query::Comment
  include Query::Initializers::PatternSearch

  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    search = google_parse_pattern
    add_search_conditions(search,
      "comments.summary",
      "COALESCE(comments.comment,'')"
    )
    super
  end
end
