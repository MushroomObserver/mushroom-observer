class Query::LocationInSet < Query::LocationBase
  def parameter_declarations
    super.merge(
      ids: [Location]
    )
  end

  def initialize_flavor
    add_id_condition("locations.id", params[:ids])
    super
  end
end
