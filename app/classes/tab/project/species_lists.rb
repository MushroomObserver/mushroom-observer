# frozen_string_literal: true

class Tab::Project::SpeciesLists < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{@project.species_lists.length} #{:SPECIES_LISTS.l}"
  end

  def path
    species_lists_path(project: @project)
  end

  def alt_title
    "species_lists"
  end
end
