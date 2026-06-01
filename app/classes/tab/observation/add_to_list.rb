# frozen_string_literal: true

class Tab::Observation::AddToList < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :list_observations_add_to_list.l
  end

  def path
    with_q_param(species_lists_edit_observations_path, @q_param)
  end
end
