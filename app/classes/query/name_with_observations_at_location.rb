# frozen_string_literal: true

class Query::NameWithObservationsAtLocation < Query::NameWithObservations
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      location: Location
    )
  end

  def initialize_flavor
    location = find_cached_parameter_instance(Location, :location)
    title_args[:location] = location.display_name
    where << "observations.location_id = '#{params[:location]}'"
    where << "observations.is_collection_location IS TRUE"
    super
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :at_location, params_with_old_by_restored)
  end
end
