# frozen_string_literal: true

module FieldSlipsHelper
  def last_observation
    return unless User.current

    ObservationView.last(User.current)
  end
end
