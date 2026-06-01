# frozen_string_literal: true

# "Cancel to observations index" action-nav link.
class Tab::Observation::Index < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :cancel_to_index.t(type: :OBSERVATION)
  end

  def path
    with_q_param(observations_path, @q_param)
  end
end
