class Query::NameWithDescriptions < Query::NameBase
  def parameter_declarations
    super.merge(
      old_by?: :string
    )
  end

  def initialize_flavor
    add_join(:name_descriptions)
    super
  end

  def coerce_into_name_description_query
    Query.lookup(:NameDescription, :all, params_with_old_by_restored)
  end
end
