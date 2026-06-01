# frozen_string_literal: true

class Tab::Observation::OfLookAlikes < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_observation_look_alikes.l
  end

  def path
    observations_path(name: @name.id, look_alikes: "1")
  end

  def model
    @name
  end
end
