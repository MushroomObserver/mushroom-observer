# frozen_string_literal: true

module FieldSlipsHelper
  def previous_observation(observation)
    return unless User.current

    ObservationView.previous(User.current, observation)
  end

  def foray_recorder?(field_slip)
    project = field_slip&.project
    return false unless project

    project.is_admin?(User.current) && project.happening?
  end
end
