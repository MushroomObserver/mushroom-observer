# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module Admin
        # Admin tab landing page. Edit/Delete project and links to
        # Members and Project Aliases.
        class Show < Views::Base
          register_output_helper :add_project_banner
          register_output_helper :add_page_title
          register_output_helper :edit_button, mark_safe: true
          register_output_helper :destroy_button, mark_safe: true
          register_value_helper :container_class

          def initialize(project:, user:)
            super()
            @project = project
            @user = user
          end

          def view_template
            add_project_banner(@project)
            add_page_title(:show_project_admin_title.l)
            container_class(:wide)

            render_panel
          end

          private

          def render_panel
            render(Components::Panel.new(panel_id: "project_admin")) do |panel|
              panel.with_body { render_actions }
            end
          end

          def render_actions
            div(class: "mb-3") do
              edit_button(target: @project, class: button_class)
              destroy_button(target: @project, class: button_class)
            end
            div { render_members_link }
            div(class: "mt-2") { render_aliases_link }
          end

          def button_class
            "btn btn-default btn-lg my-2 mr-2"
          end

          def render_members_link
            count = @project.user_group.users.count
            a(
              href: project_members_path(@project.id),
              class: button_class
            ) { plain("#{count} #{:MEMBERS.l}") }
          end

          def render_aliases_link
            count = @project.aliases.length
            a(
              href: project_aliases_path(project_id: @project.id),
              class: button_class
            ) { plain("#{count} #{:PROJECT_ALIASES.l}") }
          end
        end
      end
    end
  end
end
