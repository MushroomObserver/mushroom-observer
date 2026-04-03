# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module Locations
        # Phlex view for the project locations index page.
        # Replaces locations/index.html.erb.
        class Index < Views::Base
          register_output_helper :add_project_banner
          register_value_helper :container_class

          def initialize(project:, locations:)
            super()
            @project = project
            @locations = locations
          end

          def view_template
            add_project_banner(@project)
            container_class(:wide)

            render_table
          end

          private

          def render_table
            table(class: "table table-striped " \
                         "table-project-members mt-3") do
              thead do
                tr do
                  th { plain(:LOCATION.t) }
                  th { plain(:PROJECT_ALIASES.t) }
                end
              end
              tbody do
                @locations.each { |loc| render_row(loc) }
              end
            end
          end

          def render_row(loc)
            tr do
              td(class: "align-middle") do
                a(href: checklist_path(
                  project_id: @project.id,
                  location_id: loc.id
                )) { plain(loc.display_name) }
              end
              td(class: "align-middle") do
                render(Components::ProjectAliases.new(
                         project: @project, target: loc
                       ))
              end
            end
          end
        end
      end
    end
  end
end
