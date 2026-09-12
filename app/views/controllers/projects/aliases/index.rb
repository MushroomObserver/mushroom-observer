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

      render(Views::Controllers::Projects::AdminSubtabs.new(
               project: @project, current_subtab: "aliases"
             ))

      render(Table.new(project_aliases: @project_aliases))

      a(href: new_project_alias_path(
        project_id: @project.id
      )) { plain(:project_alias_new.t) }
    end
  end
end
