class Query::LocationWithDescriptions < Query::LocationBase
  def parameter_declarations
    super.merge(
      old_by?: :string
    )
  end

  def initialize_flavor
    add_join(:location_descriptions)
    super
  end

  def coerce_into_location_description_query
    Query.lookup(:LocationDescription, :all, params_with_old_by_restored)
  end
end
