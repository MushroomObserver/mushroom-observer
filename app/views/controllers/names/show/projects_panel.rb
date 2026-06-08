# frozen_string_literal: true

# "Create New Draft For:" panel listing the projects the current user
# is a member of where this Name doesn't yet have a description.
# Rendered only when `@projects` (set by NamesController#init_projects_ivar)
# is non-empty.
class Views::Controllers::Names::Show::ProjectsPanel < Views::Base
  prop :name, ::Name
  prop :projects, _Array(::Project)

  def view_template
    render(Components::Panel.new(panel_id: "name_projects")) do |panel|
      panel.with_heading { plain(:show_name_create_draft.t) }
      panel.with_body { render_project_links }
    end
  end

  private

  def render_project_links
    @projects.each do |project|
      a(
        href: new_name_description_path(
          @name.id, project: project.id, source: :project
        )
      ) { plain(project.title) }
      br
    end
  end
end
