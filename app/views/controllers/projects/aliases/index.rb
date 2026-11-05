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

      # On the rem-basis branch (16px rem scale), this should be my-3.
      div(class: "my-4") do
        Button(
          type: :modal, name: :project_alias_new.t,
          target: new_project_alias_path(project_id: @project.id),
          modal_id: "project_alias"
        )
        Help(content: :project_aliases_help.t, well: false)
      end
      render(Table.new(project_aliases: @project_aliases))
    end
  end
end
