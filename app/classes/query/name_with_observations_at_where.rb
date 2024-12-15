# frozen_string_literal: true

class Query::NameWithObservationsAtWhere < Query::NameWithObservations
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      user_where?: :string # used to pass parameter to create_location
    )
  end

  def initialize_flavor
    location = params[:user_where]
    title_args[:where] = location
    where << "observations.where LIKE '%#{clean_pattern(location)}%'"
    where << "observations.is_collection_location IS TRUE"
    super
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :at_where, params_with_old_by_restored)
  end
end
