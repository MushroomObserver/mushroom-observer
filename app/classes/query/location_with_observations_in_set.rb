class Query::LocationWithObservationsInSet < LocationWithObservations
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      ids:        [Observation],
      old_title?: :string
    )
  end

  def initialize_flavor
    title_args[:observations] = params[:old_title] ||
                                :query_title_in_set.t(type: :observation)
    set = clean_id_set(params[:ids])
    where << "observations.id IN (#{set})"
    where << "observations.is_collection_location IS TRUE"
    super
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :in_set, params_with_old_by_restored)
  end
end
