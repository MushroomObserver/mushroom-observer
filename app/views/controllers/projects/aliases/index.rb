# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module Aliases
        # Phlex view for the project aliases index page.
        # Replaces aliases/index.html.erb.
        class Index < Views::Base
          register_output_helper :add_project_banner
          register_output_helper :add_page_title
          register_value_helper :container_class
          register_value_helper :project_alias_headers
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

            make_table(
              headers: project_alias_headers,
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
        end
      end
    end
  end
end
