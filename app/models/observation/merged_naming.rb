# frozen_string_literal: true

# Observation::MergedNaming
#
# Wraps one or more Naming records that share the same name_id within
# an occurrence. Presents a unified interface for the namings panel,
# deduplicating by name while aggregating votes and reasons.
#
class Observation::MergedNaming
  attr_reader :name_id, :name, :namings, :observation

  delegate :display_name_brief_authors, :format_name, to: :name

  def initialize(namings, observation:, occurrence: nil)
    @namings = namings
    @observation = observation
    @occurrence = occurrence
    @name_id = namings.first.name_id
    @name = namings.first.name
    @primary = pick_primary
  end

  # The naming used for form targets (vote forms, edit links, etc.)
  def primary_naming
    @primary
  end

  # Delegate id to primary naming for DOM ids, form targets, etc.
  delegate :id, to: :@primary

  delegate :observation_id, to: :@primary

  def created_at
    @namings.map(&:created_at).min
  end

  # User attribution: local naming owner, or single sibling owner,
  # or nil (meaning "See Matching Observations")
  def user
    local = local_naming
    return local.user if local

    users = @namings.map(&:user).uniq
    users.one? ? users.first : nil
  end

  # True if the user attribution should be a link to the occurrence
  def multiple_proposers?
    !local_naming && @namings.map(&:user_id).uniq.size > 1
  end

  # Votes deduplicated by user — strongest vote per user wins.
  # Each vote retains its original observation context for weighting.
  def votes
    @votes ||= deduplicated_votes
  end

  # The user's highest vote across all namings for this name
  def users_best_vote(current_user)
    user_votes = votes.select { |v| v.user_id == current_user.id }
    user_votes.max_by(&:value)
  end

  # Aggregate vote_cache computed from deduplicated votes,
  # using each vote's original observation for ownership weighting.
  def vote_cache
    @vote_cache ||= compute_vote_cache
  end

  def vote_percent
    vote_cache / Vote::MAXIMUM_VOTE * 100
  end

  # Reasons grouped by observation: local first, then siblings.
  # Returns array of [observation_or_nil, reasons] pairs.
  # nil observation means local (current observation).
  def grouped_reasons
    local_reasons + sibling_reasons
  end

  # Can this merged naming be edited? Only if local naming exists
  def local_naming
    @local_naming ||= @namings.find do |n|
      n.observation_id == @observation.id
    end
  end

  # For permission checks and compatibility
  def can_edit?(check_user)
    ln = local_naming
    ln&.can_edit?(check_user)
  end

  private

  def local_reasons
    local = local_naming
    return [] unless local

    reasons = local.reasons_array.select(&:used?)
    reasons.any? ? [[nil, reasons]] : []
  end

  def sibling_reasons
    @namings.reject { |n| n.id == local_naming&.id }.filter_map do |n|
      reasons = n.reasons_array.select(&:used?)
      [n.observation, reasons] if reasons.any?
    end
  end

  # Prefer local naming, then first sibling naming
  def pick_primary
    local_naming || @namings.first
  end

  # Keep only the strongest vote per user across all namings
  def deduplicated_votes
    all_votes = @namings.flat_map(&:votes)
    all_votes.group_by(&:user_id).map do |_uid, user_votes|
      user_votes.max_by(&:value)
    end
  end

  # Weighted vote cache: sum(val * wgt) / (sum(wgt) + 1)
  def compute_vote_cache
    total_val = 0.0
    total_wgt = 0.0
    votes.each do |vote|
      wgt = vote.user_weight
      next unless wgt.positive?

      total_val += vote.value * wgt
      total_wgt += wgt
    end
    total_wgt.positive? ? total_val / (total_wgt + 1.0) : 0.0
  end
end
