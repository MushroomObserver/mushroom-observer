# frozen_string_literal: true

module Components
  module Projects
    # Renders the project locations table with aliases and target
    # location remove buttons.
    class LocationsTable < Components::Base
      def initialize(project:, locations:, user: nil)
        super()
        @project = project
        @locations = locations
        @user = user
      end

      def view_template
        div(id: "locations_table") do
          table(class: "table table-striped " \
                       "table-project-members mt-3") do
            thead { render_header }
            tbody do
              @locations.each { |loc| render_row(loc) }
            end
          end
        end
      end

      private

      def admin?
        @project.is_admin?(@user)
      end

      def render_header
        tr do
          th { :LOCATION.t }
          th { :PROJECT_ALIASES.t }
          if admin?
            th(class: "text-center") do
              :project_target_locations_title.t
            end
          end
        end
      end

      def render_row(loc)
        tr do
          td(class: "align-middle") do
            link_to(
              loc.display_name,
              checklist_path(project_id: @project.id,
                             location_id: loc.id)
            )
          end
          td(class: "align-middle") do
            render(Components::ProjectAliases.new(
                     project: @project, target: loc
                   ))
          end
          render_target_column(loc) if admin?
        end
      end

      def render_target_column(loc)
        td(class: "align-middle text-center") do
          render_remove_button(loc) if target?(loc)
        end
      end

      def target?(loc)
        @project.target_location_ids.include?(loc.id)
      end

      def render_remove_button(loc)
        button_to(
          project_target_location_path(
            project_id: @project.id, id: loc.id
          ),
          method: :delete,
          class: "btn btn-link text-danger p-0",
          form: { data: {
            turbo: true,
            turbo_confirm:
              :project_target_location_confirm_remove.t(
                name: loc.display_name
              )
          } }
        ) do
          span(class: "glyphicon glyphicon-remove")
        end
      end
    end
  end
end
