# frozen_string_literal: true

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
    where << "species_list_observations.species_list_id = '#{spl.id}'"
    add_join(:observation_images, :observations)
    add_join(:observations, :species_list_observations)
    super
  end

  def default_order
    "name"
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :in_species_list, params_with_old_by_restored)
  end
end
