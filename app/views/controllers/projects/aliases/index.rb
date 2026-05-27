# frozen_string_literal: true

# Phlex view for the project aliases index page.
# Replaces aliases/index.html.erb.
module Views::Controllers::Projects::Aliases
  class Index < Views::Base
    register_value_helper :project_alias_rows

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

      make_table(
        headers: alias_headers,
        rows: project_alias_rows(@project_aliases),
        table_opts: {
          class: "table table-striped " \
                 "table-project-members mt-3",
          id: "index_project_alias_table"
        }
      )

      a(href: new_project_alias_path(
        project_id: @project.id
      )) { plain(:project_alias_new.t) }
    end

    private

    # `project_alias_headers` was a one-line constant array of
    # localized strings; inlined here since this is the only caller.
    def alias_headers
      [:NAME.t, :TARGET_TYPE.t, :TARGET.t, :ACTIONS.t]
    end
  end
end
