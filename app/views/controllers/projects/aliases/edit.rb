# frozen_string_literal: true

module Views::Controllers::Projects::Aliases
  # Phlex view for the edit project alias form page.
  class Edit < Views::FullPageBase
    def initialize(project_alias:, project:, user:)
      super()
      @project_alias = project_alias
      @project = project
      @user = user
    end

    def view_template
      add_project_banner(@project)
      add_page_title(
        :project_alias_edit.l(name: @project_alias.name)
      )
      container_class(:text)

      render(Views::Controllers::Projects::Aliases::Form.new(
               @project_alias, user: @user,
                               local: true
             ))
      render_links
    end

    private

    def render_links
      pid = @project_alias.project_id
      a(href: project_alias_path(
        project_id: pid, id: @project_alias.id
      )) { plain("Show") }
      plain(" | ")
      a(href: project_aliases_path(
        project_id: pid
      )) { plain("Back") }
    end
  end
end
