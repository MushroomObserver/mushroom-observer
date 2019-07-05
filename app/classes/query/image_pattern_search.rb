class Query::ImagePatternSearch < Query::ImageBase
  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    add_search_condition(search_fields, params[:pattern])
    add_join(:images_observations, :observations)
    add_join(:observations, :locations!)
    add_join(:observations, :names)
    super
  end

  def search_fields
    "CONCAT(" \
      "names.search_name," \
      "COALESCE(images.original_name,'')," \
      "COALESCE(images.copyright_holder,'')," \
      "COALESCE(images.notes,'')," \
      "observations.where" \
      ")"
  end
end
