# frozen_string_literal: true

# Action-nav for the species_list edit-projects form. Single
# cancel-to-show link. Replaces
# `Tabs::SpeciesListsHelper#species_list_edit_project_tabs`.
class Tab::SpeciesList::FormEditProject < Tab::Collection
  def initialize(list:)
    super()
    @list = list
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @list)]
  end
end
