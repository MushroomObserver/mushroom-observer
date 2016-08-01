class Query::ImagePatternSearch < Query::Image
  include Query::Initializers::PatternSearch

  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    search = google_parse_pattern
    add_search_conditions(search,
      "names.search_name",
      "COALESCE(images.original_name,'')",
      "COALESCE(images.copyright_holder,'')",
      "COALESCE(images.notes,'')",
      "IF(locations.id,locations.name,observations.where)"
    )
    add_join(:images_observations, :observations)
    add_join(:observations, :locations!)
    add_join(:observations, :names)
    super
  end
end
