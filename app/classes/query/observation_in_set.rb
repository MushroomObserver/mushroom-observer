class Query::ObservationInSet < Query::Observation
  def parameter_declarations
    super.merge(
      ids: [Observation]
    )
  end

  def initialize_flavor
    set = clean_id_set(params[:ids])
    self.where << "observations.id IN (#{set})"
    self.order = "FIND_IN_SET(observations.id,'#{set}') ASC"
    super
  end
end
