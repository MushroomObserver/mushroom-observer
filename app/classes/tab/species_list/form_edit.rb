# frozen_string_literal: true

# Action-nav for the species_list edit form. Cancel-to-show +
# upload-link. Replaces
# `Tabs::SpeciesListsHelper#species_list_form_edit_tabs`.
class Tab::SpeciesList::FormEdit < Tab::Collection
  def initialize(list:)
    super()
    @list = list
  end

  private

  def tabs
    [
      Tab::Object::Return.new(object: @list),
      Tab::SpeciesList::Upload.new(list: @list)
    ]
  end
end
