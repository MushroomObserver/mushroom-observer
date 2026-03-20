# frozen_string_literal: true

module FieldSlipsHelper
  def previous_observation(observation, user)
    return unless user

    ObservationView.previous(user, observation)
  end

  # All observations associated with a field slip, both direct
  # (field_slip_id) and indirect (via occurrence).
  # Returns array of { obs:, direct: } hashes.
  def field_slip_all_observations(field_slip)
    direct_obs = field_slip.observations.
                 includes(:name, :user, :thumb_image).to_a
    direct_ids = direct_obs.to_set(&:id)

    indirect_obs = field_slip_indirect_observations(
      direct_obs, direct_ids
    )

    direct_obs.map { |o| { obs: o, direct: true } } +
      indirect_obs.map { |o| { obs: o, direct: false } }
  end

  private

  def field_slip_indirect_observations(direct_obs, direct_ids)
    occ_ids = direct_obs.filter_map(&:occurrence_id).uniq
    return [] if occ_ids.empty?

    Observation.where(occurrence_id: occ_ids).
      where.not(id: direct_ids).
      includes(:name, :user, :thumb_image).to_a
  end
end
