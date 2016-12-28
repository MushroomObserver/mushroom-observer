class Query::ObservationInSet < Query::ObservationBase
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [Observation]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("observations")
    super
  end

  def coerce_into_image_query
    Query.lookup(:Image, :with_observations_in_set, params)
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_observations_in_set, params)
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_observations_in_set, params)
  end
end
