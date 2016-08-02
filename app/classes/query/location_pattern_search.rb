class Query::LocationPatternSearch < Query::Location
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
        "locations.name",
      ] +
      LocationDescription.all_note_fields.map do |x|
        "COALESCE(location_descriptions.#{x},'')"
      end
    add_search_conditions(search, *note_fields)
    add_join(:"location_descriptions.default!")
    super
  end
end
