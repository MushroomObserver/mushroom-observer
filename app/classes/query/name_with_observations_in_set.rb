class Query::NameWithObservationsInSet < Query::Name
  include Query::Initializers::InSet
  include Query::Initializers::ObservationFilters

  def parameter_declarations
    super.merge(
      ids: [Observation],
      old_title?: :string,
      old_by?: :string
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    initialize_in_set_flavor("observations")
    add_join("observations")
    initialize_observation_filters
    super
  end

  def default_order
    "name"
  end
end
