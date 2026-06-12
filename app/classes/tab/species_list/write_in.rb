# frozen_string_literal: true

class Tab::SpeciesList::WriteIn < Tab::Base
  def initialize(list:)
    super()
    @list = list
  end

  def title
    :species_list_show_write_in.t
  end

  def path
    new_write_in_species_list_path(id: @list.id)
  end

  def model
    @list
  end
end
