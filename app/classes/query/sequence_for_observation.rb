class Query::SequenceForObservation < Query::SequenceBase
  def parameter_declarations
    super.merge(
      observation: Observation
    )
  end

  def initialize_flavor
    obs = find_cached_parameter_instance(Observation, :observation)
    title_args[:observation] = obs.unique_format_name
    where << "sequences.observation_id = '#{obs.id}'"
    super
  end
end
