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
    reuse_images_for_observation_path(@observation.id)
  end

  def html_options
    { icon: :reuse }
  end

  def model
    @observation
  end
end
