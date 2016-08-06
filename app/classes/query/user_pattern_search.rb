class Query::UserPatternSearch < Query::UserBase
  include Query::Initializers::PatternSearch

  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    search = google_parse_pattern
    add_search_conditions(search,
      "users.login",
      "users.name"
    )
    super
  end
end
