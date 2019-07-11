class Query::ObservationPatternSearch < Query::ObservationBase
  def parameter_declarations
    super.merge(
      pattern: :string
    )
  end

  def initialize_flavor
    add_search_condition(search_fields, params[:pattern])
    add_join(:locations!)
    add_join(:names)
    super
  end

  def search_fields
    "CONCAT(" \
      "names.search_name," \
      "COALESCE(observations.notes,'')," \
      "observations.where" \
      ")"
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
    Query.lookup(new_model, :with_observations_in_set,
                 add_old_title(add_old_by(ids: result_ids)))
  end
end
