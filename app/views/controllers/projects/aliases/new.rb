# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module Aliases
        # Phlex view for the new project alias form page.
        # Replaces aliases/new.html.erb.
        class New < Views::Base
          register_output_helper :add_project_banner
          register_output_helper :add_page_title
          register_value_helper :container_class

          def initialize(project_alias:, project:, user:)
            super()
            @project_alias = project_alias
            @project = project
            @user = user
          end

          def view_template
            add_project_banner(@project)
            add_page_title(:project_alias_new.l)
            container_class(:text)

            render(Components::ProjectAliasForm.new(
                     @project_alias, user: @user,
                                     local: true
                   ))
            a(href: project_aliases_path(
              project_id: @project_alias.project_id
            )) { plain("Back") }
          end
        end
      end
    end
  end
end
