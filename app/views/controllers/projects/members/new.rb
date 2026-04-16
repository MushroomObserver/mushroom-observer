# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module Members
        # Phlex view for the add members page.
        # Replaces members/new.html.erb.
        class New < Views::Base
          register_output_helper :add_page_title
          register_output_helper :add_context_nav
          register_output_helper :post_button, mark_safe: true
          register_value_helper :container_class
          register_value_helper :project_members_form_new_tabs

          def initialize(project:, users:, project_member:,
                         user:)
            super()
            @project = project
            @users = users
            @project_member = project_member
            @user = user
          end

          def view_template
            add_page_title(
              :add_members_title.t(title: @project.title)
            )
            add_context_nav(
              project_members_form_new_tabs(project: @project)
            )
            container_class(:wide)

            render(Components::ProjectMemberForm.new(
                     @project_member, project: @project
                   ))
            render_users_table
          end

          private

          def render_users_table
            table(class: "table table-striped " \
                         "table-project-members mt-3") do
              render_table_header
              tbody do
                @users.sort_by(&:login).each do |u|
                  render_user_row(u)
                end
              end
            end
          end

          def render_table_header
            thead do
              tr do
                th { plain(:Login_name.t) }
                th { plain(:Full_name.t) }
                th
              end
            end
          end

          def render_user_row(user)
            tr do
              td { user_link(user, user.login) }
              td { plain(user.name) }
              td do
                post_button(
                  name: :ADD.t,
                  path: project_members_path(
                    project_id: @project.id,
                    candidate: user.id
                  )
                )
              end
            end
          end
        end
      end
    end
  end
end
