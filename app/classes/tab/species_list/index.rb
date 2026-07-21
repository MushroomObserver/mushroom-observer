# frozen_string_literal: true

# "Cancel to species list index" action-nav link.
class Tab::SpeciesList::Index < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :cancel_to_index.t(type: :species_list)
  end

  def path
    with_q_param(species_lists_path, @q_param)
  end
end
