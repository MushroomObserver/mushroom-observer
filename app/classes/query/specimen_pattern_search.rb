class Query::SpecimenPatternSearch < Query::Specimen
  include Query::Initializers::PatternSearch

  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize
    search = google_parse_pattern
    add_search_conditions(search,
      "users.login",
      "users.name"
    )
<<<<<<< HEAD
  super
=======
    super
>>>>>>> a3ce6dd949116c5773fa3e3c3496518e74a892cb
  end
end
