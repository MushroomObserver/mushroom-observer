class Query::ObservationOfChildren < Query::Observation
  include Query::Initializers::OfChildren

  def parameter_declarations
    super.merge(
      name: Name,
      all?: :boolean
    )
  end

  def initialize_flavor
    name = find_cached_parameter_instance(Name, :name)
    title_args[:name] = name.display_name
    add_name_condition(name)
    super
  end

  def default_order
    "name"
  end
end
