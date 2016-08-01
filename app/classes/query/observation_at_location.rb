class Query::ObservationAtLocation < Query::Observation
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
end
