module Query
  # Names with observations in a given species list.
  class NameWithObservationsInSpeciesList < Query::NameBase
    include Query::Initializers::ObservationFilters

    def parameter_declarations
      super.merge(
        species_list: SpeciesList,
        old_by?:      :string
      ).merge(observation_filter_parameter_declarations)
    end

    def initialize_flavor
      spl = find_cached_parameter_instance(SpeciesList, :species_list)
      title_args[:species_list] = spl.format_name
      add_join(:observations, :observations_species_lists)
      where << "observations_species_lists.species_list_id = '#{spl.id}'"
      initialize_observation_filters
      super
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :in_species_list, params_with_old_by_restored)
    end
  end
end
