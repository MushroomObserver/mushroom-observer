# frozen_string_literal: true

# "N Names" link on the species-list show page's action-tab strip --
# the checklist of names in this list. `project:` carries the
# project context through when the list is viewed under a project
# (e.g. the obs/species-list panel on a project page).
class Tab::SpeciesList::Names < Tab::Base
  def initialize(species_list:, project: nil, count: nil)
    super()
    @species_list = species_list
    @project = project
    @count = count
  end

  def title
    return :names.ti unless @count

    "#{@count} #{:names.ti}"
  end

  def path
    checklist_path(
      { species_list_id: @species_list.id, project: @project&.id }.compact
    )
  end

  def alt_title
    "names"
  end
end
