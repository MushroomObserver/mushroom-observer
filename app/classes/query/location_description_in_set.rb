class Query::LocationDescriptionInSet < Query::LocationDescriptionBase
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [LocationDescription]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("location_descriptions")
    super
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_descriptions_in_set, params)
  end
end
