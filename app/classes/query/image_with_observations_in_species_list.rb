class Query::ImageWithObservationsInSpeciesList < Query::ImageBase
  include Query::Initializers::ObservationFilters

  def parameter_declarations
    super.merge(
      species_list: SpeciesList
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    species_list = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = species_list.format_name
    add_join(:images_observations, :observations)
    add_join(:observations, :observations_species_lists)
    self.where << "observations_species_lists.species_list_id = '#{species_list.id}'"
    initialize_observation_filters
    super
  end

  def default_order
    "name"
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :in_species_list, params)
  end
end
