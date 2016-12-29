module Query
  # Simple user search.
  class UserPatternSearch < Query::UserBase
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
        "users.login",
        "users.name"
      ]
    end
  end
end
