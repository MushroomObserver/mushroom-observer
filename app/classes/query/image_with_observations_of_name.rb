class Query::ImageWithObservationsOfName < Query::Image
  include Query::Initializers::ObservationFilters
  include Query::Initializers::OfName

  def parameter_declarations
    super.merge(
      name:          :name,
      synonyms?:     { string: [:no, :all, :exclusive] },
      nonconsensus?: { string: [:no, :all, :exclusive] },
      project?:      Project,
      species_list?: SpeciesList,
      user?:         User
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    give_parameter_defaults
    names = get_target_names
    choose_a_title(names)
    add_join(:images_observations, :observations)
    add_name_conditions(names)
    restrict_to_one_project
    restrict_to_one_species_list
    restrict_to_one_user
    title_args[:tag] = title_args[:tag].to_s.sub("title", "title_with_observations").to_sym
    initialize_observation_filters
    super
  end

  def add_join_to_observations(table)
    add_join(:observations, table)
  end

  def default_order
    "name"
  end
end
