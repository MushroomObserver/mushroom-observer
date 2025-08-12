# frozen_string_literal: true

module FieldSlipsHelper
  def previous_observation(observation, user)
    return unless user

    ObservationView.previous(user, observation)
  end
end
