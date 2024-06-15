# frozen_string_literal: true

module FieldSlipsHelper
  def previous_observation(observation)
    return unless User.current

    ObservationView.previous(User.current, observation)
  end
end
