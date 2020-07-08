# frozen_string_literal: true

class Query::LocationWithObservationsInSpeciesList <
      Query::LocationWithObservations
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      species_list: SpeciesList
    )
  end

  def initialize_flavor
    glue_table = :observations_species_lists
    species_list = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = species_list.format_name
    add_join(:observations, glue_table)
    where << "#{glue_table}.species_list_id = '#{species_list.id}'"
    where << "observations.is_collection_location IS TRUE"
    super
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :in_species_list, params_with_old_by_restored)
  end
end
