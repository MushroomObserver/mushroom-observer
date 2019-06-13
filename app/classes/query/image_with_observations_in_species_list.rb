class Query::ImageWithObservationsInSpeciesList < Query::ImageWithObservations
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      species_list: SpeciesList
    )
  end

  def initialize_flavor
    spl = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = spl.format_name
    where << "observations_species_lists.species_list_id = '#{spl.id}'"
    add_join(:images_observations, :observations)
    add_join(:observations, :observations_species_lists)
    super
  end

  def default_order
    "name"
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :in_species_list, params_with_old_by_restored)
  end
end
