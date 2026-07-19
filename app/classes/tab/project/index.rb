# frozen_string_literal: true

# "Cancel to projects index" action-nav link — rendered in
# action-nav contexts (project form pages, member form pages).
class Tab::Project::Index < Tab::Base
  def title
    :cancel_to_index.t(type: :project)
  end

  def path
    projects_path
  end
end
