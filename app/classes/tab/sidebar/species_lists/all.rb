# frozen_string_literal: true

# Sidebar species_lists nav: all lists.
class Tab::Sidebar::SpeciesLists::All < Tab::Base
  def title
    :app_all_lists.t
  end

  def path
    species_lists_path
  end
end
