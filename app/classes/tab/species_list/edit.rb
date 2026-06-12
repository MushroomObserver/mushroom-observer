# frozen_string_literal: true

class Tab::SpeciesList::Edit < Tab::Base
  def initialize(list:)
    super()
    @list = list
  end

  def title
    :species_list_show_edit.t
  end

  def path
    edit_species_list_path(@list.id)
  end

  def model
    @list
  end
end
