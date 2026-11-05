# frozen_string_literal: true

module Views::Controllers::Projects::Aliases
  # Phlex view for the new project alias form page.
  class New < Views::FullPageBase
    prop :project_alias, ::ProjectAlias
    prop :project, ::Project
    prop :user, ::User

    def view_template
      add_project_banner(@project)
      add_new_title(:create_object, :project_alias)
      container_class(:text)

      render(Views::Controllers::Projects::Aliases::Form.new(
               @project_alias, user: @user
             ))
      a(href: project_aliases_path(
        project_id: @project_alias.project_id
      )) { plain("Back") }
    end
  end
end
