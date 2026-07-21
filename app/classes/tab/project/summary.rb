# frozen_string_literal: true

class Tab::Project::Summary < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    :summary.ti
  end

  def path
    project_path(id: @project.id)
  end

  def alt_title
    "summary"
  end

  # Banner's `current_tab` is derived from `controller_name`, which
  # is "projects" for the project show page. The Summary tab is the
  # only one whose nav_key diverges from its `alt_title` selector.
  def nav_key
    "projects"
  end
end
