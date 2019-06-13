class Query::ObservationInSet < Query::ObservationBase
  def parameter_declarations
    super.merge(
      ids: [Observation]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end

  def coerce_into_image_query
    do_coerce(:Image)
  end

  def coerce_into_location_query
    do_coerce(:Location)
  end

  def coerce_into_name_query
    do_coerce(:Name)
  end

  def do_coerce(new_model)
    Query.lookup(new_model, :with_observations_in_set, params_plus_old_by)
  end
end
