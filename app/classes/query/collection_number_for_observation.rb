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
    where << "observation_collection_numbers.observation_id = '#{obs.id}'"
    add_join(:observation_collection_numbers)
    super
  end
end
