class Query::HerbariumPatternSearch < Query::HerbariumBase
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
      "herbaria.code," \
      "herbaria.name," \
      "COALESCE(herbaria.description,'')," \
      "COALESCE(herbaria.mailing_address,'')" \
      ")"
  end
end
