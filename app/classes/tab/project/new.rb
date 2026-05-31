# frozen_string_literal: true

# "Add Project" action-nav link — rendered on the projects index.
class Tab::Project::New < Tab::Base
  def title
    :list_projects_add_project.t
  end

  def path
    new_project_path
  end
end
