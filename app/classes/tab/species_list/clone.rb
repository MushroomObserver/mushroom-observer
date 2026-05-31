# frozen_string_literal: true

class Tab::SpeciesList::Clone < Tab::Base
  def initialize(list:)
    super()
    @list = list
  end

  def title
    :species_list_show_clone_list.t
  end

  def path
    new_species_list_path(clone: @list.id)
  end

  def model
    @list
  end
end
