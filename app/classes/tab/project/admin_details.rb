# frozen_string_literal: true

class Tab::Project::AdminDetails < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    :show_project_admin_details_tab.l
  end

  def path
    project_admin_path(project_id: @project.id)
  end

  def alt_title
    "details"
  end
end
