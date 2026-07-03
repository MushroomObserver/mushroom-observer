# frozen_string_literal: true

# Sidebar species_lists nav: create a new list. User-only.
class Tab::Sidebar::SpeciesLists::New < Tab::Base
  def title
    :app_create_list.t
  end

  def path
    new_species_list_path
  end
end
