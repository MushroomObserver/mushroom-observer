# frozen_string_literal: true

# "View matching observations" link — the occurrence this
# observation belongs to. Shown icon-only in the Matching
# Observations panel's heading_links when the occurrence has
# siblings.
class Tab::Observation::MatchingObservations < Tab::Base
  def initialize(occurrence:)
    super()
    @occurrence = occurrence
  end

  def title
    :show_observation_matching_observations.l
  end

  def path
    occurrence_path(@occurrence.id)
  end

  def html_options
    { icon: :matrix }
  end

  def model
    @occurrence
  end
end
