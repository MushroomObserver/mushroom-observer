class Query::ObservationOfChildren < Query::Observation
  include Query::OfChildren

  def self.parameter_declarations
    super.merge(
      name: Name,
      all?: :boolean
    )
  end

  def initialize
    name = find_cached_parameter_instance(Name, :name)
    title_args[:name] = name.display_name
    params[:by] ||= "name"
    add_name_condition(name)
    add_join(:names)
  end
end
