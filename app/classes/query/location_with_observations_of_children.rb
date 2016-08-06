class Query::LocationWithObservationsOfChildren < Query::LocationBase
  include Query::Initializers::ObservationFilters
  include Query::Initializers::OfChildren

  def parameter_declarations
    super.merge(
      name: Name,
      all?: :boolean
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    name = find_cached_parameter_instance(Name, :name)
    title_args[:name] = name.display_name
    add_name_condition(name)
    add_join(:observations)
    add_join(:observations, :names)
    initialize_observation_filters
    super
  end
end
