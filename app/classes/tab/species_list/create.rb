# frozen_string_literal: true

class Tab::SpeciesList::Create < Tab::Base
  def title
    :create_object.t(type: :species_list)
  end

  def path
    new_species_list_path
  end
end
