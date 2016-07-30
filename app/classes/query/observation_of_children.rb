class Query::ObservationOfChildren < Query::Observation
  include Query::OfChildren

  def parameter_declarations
    super.merge(
      name: Name,
      all?: :boolean
    )
  end

  def initialize
    name = find_cached_parameter_instance(Name, :name)
    title_args[:name] = name.display_name
    add_name_condition(name)
    params[:by] ||= "name"
    super
  end
end
