module Query
  # Names with observations created by a given user.
  class NameWithObservationsByUser < NameWithObservations
    include Query::Initializers::ContentFilters

    def parameter_declarations
      super.merge(
        user: User
      )
    end

    def initialize_flavor
      user = find_cached_parameter_instance(User, :user)
      title_args[:user] = user.legal_name
      add_join(:observations)
      where << "observations.user_id = '#{user.id}'"
      initialize_content_filters(Observation)
      super
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :by_user, params_with_old_by_restored)
    end
  end
end
