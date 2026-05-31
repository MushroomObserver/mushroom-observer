# frozen_string_literal: true

class Tab::Project::Admin < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    :show_project_admin_tab.l
  end

  def path
    project_admin_path(project_id: @project.id)
  end

  def alt_title
    "admin"
  end
end
