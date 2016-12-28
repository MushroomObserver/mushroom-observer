class Query::ObservationOfChildren < Query::ObservationBase
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
    add_join(:names)
    super
  end

  def default_order
    "name"
  end

  def coerce_into_image_query
    Query.lookup(:Image, :with_observations_of_children, params)
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_observations_of_children, params)
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_observations_of_children, params)
  end
end
