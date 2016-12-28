class Query::NameWithDescriptions < Query::NameBase
  def parameter_declarations
    super
  end

  def initialize_flavor
    add_join(:"name_descriptions")
    super
  end

  def coerce_into_name_description_query
    Query.lookup(:NameDescription, :all, params)
  end
end
