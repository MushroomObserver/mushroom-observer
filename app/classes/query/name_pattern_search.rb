class Query::NamePatternSearch < Query::Name
  include Query::Initializers::PatternSearch

  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    search = google_parse_pattern
    note_fields =
      [
        "names.search_name",
        "COALESCE(names.citation,'')",
        "COALESCE(names.notes,'')"
      ] +
      NameDescription.all_note_fields.map do |x|
        "COALESCE(name_descriptions.#{x},'')"
      end
    add_search_conditions(search, *note_fields)
    add_join(:"name_descriptions.default!")
    super
  end
end
