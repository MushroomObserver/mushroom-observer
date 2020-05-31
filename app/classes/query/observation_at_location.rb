# frozen_string_literal: true

class Query::ObservationAtLocation < Query::ObservationBase
  def parameter_declarations
    super.merge(
      location: Location
    )
  end

  def initialize_flavor
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    where << "observations.location_id = '#{location.id}'"
    super
  end

  def default_order
    "name"
  end

  def coerce_into_image_query
    do_coerce(:Image)
  end

  def coerce_into_location_query
    # This should result in a query with exactly one result, so the resulting
    # index should immediately display the actual location instead of an
    # index.  Thus title and saving the old sort order are unimportant.
    Query.lookup(:Location, :in_set, ids: params[:location])
  end

  def coerce_into_name_query
    do_coerce(:Name)
  end

  def do_coerce(new_model)
    Query.lookup(new_model, :with_observations_at_location,
                 params_plus_old_by)
  end
end
