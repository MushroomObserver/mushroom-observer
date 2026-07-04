# frozen_string_literal: true

# "Create an occurrence from this observation" link — stands in as
# the Matching Observations panel's whole heading when the
# observation doesn't belong to an occurrence yet.
class Tab::Observation::AddMatchingObservations < Tab::Base
  def initialize(obs:)
    super()
    @obs = obs
  end

  def title
    :show_observation_add_matching_observations.l
  end

  def path
    new_occurrence_path(observation_id: @obs.id)
  end

  def html_options
    { icon: :matrix }
  end

  def model
    @obs
  end
end
