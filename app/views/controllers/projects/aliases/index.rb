# frozen_string_literal: true

# Phlex view for the project aliases index page.
# Replaces aliases/index.html.erb.
module Views::Controllers::Projects::Aliases
  class Index < Views::Base
    def initialize(project:, project_aliases:)
      super()
      @project = project
      @project_aliases = project_aliases
    end

    def view_template
      add_project_banner(@project)
      add_page_title(:PROJECT_ALIASES.l)
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
