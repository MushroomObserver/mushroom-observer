# frozen_string_literal: true

class Tab::SpeciesList::Create < Tab::Base
  def title
    :create_object.t(type: :SPECIES_LIST)
  end

  def path
    new_species_list_path
  end
end
