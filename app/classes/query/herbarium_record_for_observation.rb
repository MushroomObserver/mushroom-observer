# frozen_string_literal: true

class Query::HerbariumRecordForObservation < Query::HerbariumRecordBase
  def parameter_declarations
    super.merge(
      observation: Observation
    )
  end

  def initialize_flavor
    obs = find_cached_parameter_instance(Observation, :observation)
    title_args[:observation] = obs.unique_format_name
    where << "observation_herbarium_records.observation_id = '#{obs.id}'"
    add_join(:observation_herbarium_records)
    super
  end
end
