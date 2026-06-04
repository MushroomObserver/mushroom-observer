# frozen_string_literal: true

# Sidebar indexes nav: projects index.
class Tab::Sidebar::Indexes::Projects < Tab::Base
  def title
    :PROJECTS.t
  end

  def path
    projects_path
  end

  def html_options
    { id: "nav_projects_link" }
  end
end
