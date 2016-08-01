class Query::NameWithObservationsAtLocation < Query::Name
  def parameter_declarations
    super.merge(
      location: Location,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    )
  end

  def initialize_flavor
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    add_join(:observations)
    self.where << "observations.location_id = '#{params[:location]}'"
    self.where << "observations.is_collection_location IS TRUE"
    initialize_observation_filters

    super
  end

  def default_order
    "name"
  end
end
