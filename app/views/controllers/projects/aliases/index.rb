# frozen_string_literal: true

# Phlex view for the project aliases index page.
module Views::Controllers::Projects::Aliases
  class Index < Views::FullPageBase
    prop :project, ::Project
    prop :project_aliases, _Array(::ProjectAlias)

    def view_template
      add_project_banner(@project)
      add_page_title(:project_aliases.ti)
      container_class(:wide)

      ContentPadded do
        render_rubric
        Help(content: :project_aliases_help.t, well: false)
      end
      render(Table.new(project_aliases: @project_aliases))
    end

    private

    def render_rubric
      div(class: "d-flex align-items-center mb-2") do
        h4(class: "font-weight-bold mr-3 my-0") { plain(:aliases.ti) }
        Button(
          type: :add,
          target: new_project_alias_path(project_id: @project.id),
          modal_id: "project_alias"
        )
      end
    end
  end
end
