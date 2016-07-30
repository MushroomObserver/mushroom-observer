class Query::UserPatternSearch < Query::User
  def self.parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize
    pattern = params[:pattern].to_s.strip_squeeze
    clean  = clean_pattern(pattern)
    search = google_parse(clean)

    self.where += google_conditions(search,
                                    "CONCAT(users.login,users.name)")
  end
end
