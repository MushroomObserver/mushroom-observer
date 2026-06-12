# frozen_string_literal: true

class Tab::Observation::HideThumbnailMap < Tab::Base
  def initialize(observation:)
    super()
    @observation = observation
  end

  def title
    :show_observation_hide_map.l
  end

  def path
    javascript_hide_thumbnail_map_path(id: @observation.id)
  end

  def html_options
    { icon: :hide }
  end

  def model
    @observation
  end
end
