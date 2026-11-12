# frozen_string_literal: true

# Member-facing observation sub-tab: map of the project's
# observations (`?q=...` scoped query carried over via `q_param`).
class Tab::Project::ObservationMap < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :map.ti
  end

  def path
    with_q_param(map_observations_path, @q_param)
  end

  def alt_title
    "map"
  end
end
