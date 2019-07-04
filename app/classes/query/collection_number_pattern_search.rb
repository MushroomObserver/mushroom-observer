class Query::CollectionNumberPatternSearch < Query::CollectionNumberBase
  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    add_search_condition(search_fields, params[:pattern])
    super
  end

  def search_fields
    "CONCAT(" \
      "collection_numbers.name," \
      "collection_numbers.number" \
      ")"
  end
end
