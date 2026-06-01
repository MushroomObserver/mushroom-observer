# frozen_string_literal: true

class Tab::Observation::Edit < Tab::Base
  def initialize(observation:)
    super()
    @observation = observation
  end

  def title
    :edit_object.t(type: Observation)
  end

  def path
    edit_observation_path(@observation.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @observation
  end
end
