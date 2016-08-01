class Query::NameWithObservationsInSpeciesList < Query::Name
  def parameter_declarations
    super.merge(
      species_list: SpeciesList,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    )
  end

  def initialize_flavor
    species_list = find_cached_parameter_instance(SpeciesList,
                                                  :species_list)
    title_args[:species_list] = species_list.format_name
    add_join(:observations, :observations_species_lists)
    self.where << "observations_species_lists.species_list_id = '#{params[:species_list]}'"
    initialize_observation_filters
    super
  end

  def default_order
    "name"
  end
end
