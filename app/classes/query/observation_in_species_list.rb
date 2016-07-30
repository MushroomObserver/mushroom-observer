class Query::ObservationInSpeciesList < Query::Observation
  def self.parameter_declarations
    super.merge(
      species_list: SpeciesList
    )
  end

  def initialize
    species_list = find_cached_parameter_instance(SpeciesList, :species_list)
    title_args[:species_list] = species_list.format_name
    # Why was this in here?? The sort initializer should add join to names
    # later if it really does sort by name. (see params[:by] default below)
    # add_join(:names)
    add_join(:observations_species_lists)
    self.where << "observations_species_lists.species_list_id = '#{species_list.id}'"
    params[:by] ||= "name"
  end
end
