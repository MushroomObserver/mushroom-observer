class Query::ObservationInSet < Query::ObservationBase
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [Observation]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("observations")
    super
  end
end
