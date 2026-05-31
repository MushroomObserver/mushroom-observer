# frozen_string_literal: true

class Tab::SpeciesList::AddRemoveFromAnotherList < Tab::Base
  def initialize(list:, q_param: nil)
    super()
    @list = list
    @q_param = q_param
  end

  def title
    :species_list_show_add_remove_from_another_list.t
  end

  def path
    with_q_param(
      species_lists_edit_observations_path(species_list: { title: @list.id }),
      @q_param
    )
  end

  def model
    @list
  end
end
