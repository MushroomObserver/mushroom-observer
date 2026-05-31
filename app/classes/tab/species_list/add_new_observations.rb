# frozen_string_literal: true

class Tab::SpeciesList::AddNewObservations < Tab::Base
  def initialize(list:)
    super()
    @list = list
  end

  def title
    :species_list_show_add_new_observations.t
  end

  def path
    new_write_in_species_list_path(@list.id)
  end

  def html_options
    { help: :species_list_show_add_new_observations_help.l }
  end

  def model
    @list
  end
end
