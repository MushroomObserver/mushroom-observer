# frozen_string_literal: true

class Tab::Observation::AssignUndefinedLocation < Tab::Base
  def initialize(where:, q_param: nil)
    super()
    @where = where
    @q_param = q_param
  end

  def title
    :list_observations_location_merge.l
  end

  def path
    with_q_param(
      matching_locations_for_observations_path(where: @where), @q_param
    )
  end
end
