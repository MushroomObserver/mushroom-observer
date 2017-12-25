module Query
  # Simple image search.
  class ImagePatternSearch < Query::ImageBase
    include Query::Initializers::PatternSearch

    def parameter_declarations
      super.merge(
        pattern: :string
      )
    end

    def initialize_flavor
      initialize_search
      add_join(:images_observations, :observations)
      add_join(:observations, :locations!)
      add_join(:observations, :names)
      super
    end

    def initialize_search
      add_search_conditions(
        google_parse_pattern,
        "names.search_name",
        "COALESCE(images.original_name,'')",
        "COALESCE(images.copyright_holder,'')",
        "COALESCE(images.notes,'')",
        "observations.where"
      )
    end
  end
end
