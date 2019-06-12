class Query::UserPatternSearch < Query::UserBase
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
      "users.login," \
      "users.name"
      ")"
  end
end
