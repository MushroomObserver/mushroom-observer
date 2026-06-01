# frozen_string_literal: true

class Tab::Observation::OfName < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_observation_more_like_this.l
  end

  def path
    observations_path(name: @name.id)
  end

  def model
    @name
  end
end
