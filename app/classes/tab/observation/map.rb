# frozen_string_literal: true

# "Map" link on the observations index. The link has a
# `links#disable` Stimulus data-action so clicking it disables the
# button while the map page loads (long async work — gives
# feedback to the user).
class Tab::Observation::Map < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :show_object.t(type: :map)
  end

  def path
    map_observations_path(q: @q_param)
  end

  def html_options
    { data: { action: "links#disable" } }
  end
end
