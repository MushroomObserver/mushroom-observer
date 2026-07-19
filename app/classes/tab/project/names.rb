# frozen_string_literal: true

class Tab::Project::Names < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{@project.name_count} #{:names.ti}"
  end

  def path
    checklist_path(project_id: @project.id)
  end

  def alt_title
    "checklists"
  end
end
