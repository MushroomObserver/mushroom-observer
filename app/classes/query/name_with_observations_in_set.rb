# frozen_string_literal: true

class Query::NameWithObservationsInSet < Query::NameWithObservations
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      ids: [Observation],
      old_title?: :string
    )
  end

  def initialize_flavor
    title_args[:observations] = params[:old_title] ||
                                :query_title_in_set.t(type: :observation)
    initialize_in_set_flavor("observations")
    super
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :in_set, params_with_old_by_restored)
  end
end
