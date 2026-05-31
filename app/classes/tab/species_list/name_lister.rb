# frozen_string_literal: true

class Tab::SpeciesList::NameLister < Tab::Base
  def title
    :name_lister_title.t
  end

  def path
    species_lists_new_name_lister_path
  end
end
