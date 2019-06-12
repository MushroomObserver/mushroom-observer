class Query::LocationDescriptionInSet < Query::LocationDescriptionBase
  def parameter_declarations
    super.merge(
      ids:     [LocationDescription],
      old_by?: :string
    )
  end

  def initialize_flavor
    add_id_condition("location_descriptions.id", params[:ids])
    super
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_descriptions_in_set, params_plus_old_by)
  end
end
