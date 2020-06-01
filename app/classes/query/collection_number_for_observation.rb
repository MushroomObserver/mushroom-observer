# frozen_string_literal: true

class Query::CollectionNumberForObservation < Query::CollectionNumberBase
  def parameter_declarations
    super.merge(
      observation: Observation
    )
  end

  def initialize_flavor
    obs = find_cached_parameter_instance(Observation, :observation)
    title_args[:observation] = obs.unique_format_name
    where << "collection_numbers_observations.observation_id = '#{obs.id}'"
    add_join(:collection_numbers_observations)
    super
  end
end
