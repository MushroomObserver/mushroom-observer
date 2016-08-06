class Query::ObservationOfName < Query::ObservationBase
  include Query::Initializers::OfName

  def parameter_declarations
    super.merge(
      of_name_parameter_declarations
    )
  end

  def initialize_flavor
    give_parameter_defaults
    names = get_target_names
    choose_a_title(names)
    add_name_conditions(names)
    restrict_to_one_project
    restrict_to_one_species_list
    restrict_to_one_user
    super
  end

  def add_join_to_observations(table)
    add_join(table)
  end
end
