# frozen_string_literal: true

# Non-tab helpers for project-related views — currently just the
# project-banner `content_for` setter, which is called from many
# Phlex views and ERB views via `register_value_helper`.
# Sort options live on `ProjectsController#index_sort_options`.
module ProjectsHelper
  def add_project_banner(project)
    content_for(:project_banner) do
      render(Views::Controllers::Projects::Banner.new(
               project: project,
               user: User.current,
               current_tab: active_project_tab
             ))
    end
  end
end
