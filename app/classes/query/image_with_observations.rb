class Query::ImageWithObservations < Query::Image
  include Query::Initializers::ObservationFilters

  def parameter_declarations
    super.merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    add_join(:images_observations, :observations)
    initialize_observation_filters
    super
  end

  def default_order
    "name"
  end
end
