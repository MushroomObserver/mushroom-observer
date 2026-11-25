# frozen_string_literal: true

class Tab::Observation::ReuseImages < Tab::Base
  def initialize(observation:)
    super()
    @observation = observation
  end

  def title
    :show_observation_reuse_image.l
  end

  def path
    images_reuse_path(target_type: "Observation", target_id: @observation.id)
  end

  def html_options
    { icon: :reuse }
  end

  def model
    @observation
  end
end
