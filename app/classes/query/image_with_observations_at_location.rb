class Query::ImageWithObservationsAtLocation < Query::ImageBase
  include Query::Initializers::ObservationFilters

  def parameter_declarations
    super.merge(
      location: Location
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    add_join(:images_observations, :observations)
    self.where << "observations.location_id = '#{params[:location]}'"
    self.where << "observations.is_collection_location IS TRUE"
    initialize_observation_filters
    super
  end

  def default_order
    "name"
  end
end
