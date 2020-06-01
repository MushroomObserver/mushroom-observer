# frozen_string_literal: true

class Query::LocationWithObservationsByUser < Query::LocationWithObservations
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      user: User
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    where << "observations.user_id = '#{user.id}'"
    where << "observations.is_collection_location IS TRUE"
    super
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :by_user, params_with_old_by_restored)
  end
end
