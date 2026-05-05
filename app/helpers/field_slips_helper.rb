# frozen_string_literal: true

module FieldSlipsHelper
  def previous_observation(observation, user)
    return unless user

    ObservationView.previous(user, observation)
  end

  # All observations associated with a field slip through its
  # occurrence. Returns array of observations.
  def field_slip_all_observations(field_slip)
    field_slip.observations.
      includes(:name, :user, :thumb_image).to_a
  end
end
