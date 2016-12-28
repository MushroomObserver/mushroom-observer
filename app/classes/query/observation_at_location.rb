class Query::ObservationAtLocation < Query::ObservationBase
  def parameter_declarations
    super.merge(
      location: Location
    )
  end

  def initialize_flavor
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    self.where << "observations.location_id = '#{location.id}'"
    super
  end

  def default_order
    "name"
  end

  def coerce_into_image_query
    Query.lookup(:Image, :with_observations_at_location, params)
  end

  def coerce_into_location_query
    Query.lookup(:Location, :in_set, ids: params[:location])
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_observations_at_location, params)
  end
end
