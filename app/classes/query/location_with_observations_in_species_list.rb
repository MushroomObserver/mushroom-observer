module Query
  # Locations with observations in a given species list.
  class LocationWithObservationsInSpeciesList < LocationWithObservations
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
      initialize_content_filters(Observation)
      super
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :in_species_list, params_with_old_by_restored)
    end
  end
end
