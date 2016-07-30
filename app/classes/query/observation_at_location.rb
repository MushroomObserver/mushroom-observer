class Query::ObservationAtLocation < Query::Observation
  def self.parameter_declarations
    super.merge(
      location: Location
    )
  end

  def initialize
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    add_join(:names)
    self.where << "locations.location_id = '#{params[:location]}'"
    params[:by] ||= "name"
  end
end
