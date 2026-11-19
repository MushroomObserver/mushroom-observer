# frozen_string_literal: true

module Views::Controllers::Projects::Aliases
  # Phlex view for the edit project alias form page.
  class Edit < Views::FullPageBase
    prop :project_alias, ::ProjectAlias
    prop :project, ::Project
    prop :user, ::User

    def view_template
      add_project_banner(@project)
      add_edit_title(@project_alias, user: @user)
      container_class(:text)

      render(Views::Controllers::Projects::Aliases::Form.new(
               @project_alias, user: @user
             ))
      render_links
    end

    private

    def render_links
      pid = @project_alias.project_id
      Link(type: :get, name: "Show", target: project_alias_path(
        project_id: pid, id: @project_alias.id
      ))
      plain(" | ")
      Link(type: :get, name: "Back", target: project_aliases_path(
        project_id: pid
      ))
    end
  end
end
