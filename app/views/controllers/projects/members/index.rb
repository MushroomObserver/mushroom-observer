# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module Members
        # Phlex view for the project members index page.
        # Replaces members/index.html.erb.
        class Index < Views::Base
          register_output_helper :add_project_banner
          register_value_helper :container_class

          def initialize(project:, users:, project_member:,
                         user:)
            super()
            @project = project
            @users = users
            @project_member = project_member
            @user = user
          end

          def view_template
            add_project_banner(@project)
            container_class(:wide)

            render(Components::ProjectMemberForm.new(
                     @project_member, project: @project
                   ))
            render_table
          end

          private

          def render_table
            table(class: "table table-striped " \
                         "table-project-members mt-3") do
              render_header
              tbody do
                @users.sort_by(&:login).each do |u|
                  render_row(u)
                end
              end
            end
          end

          def render_header
            thead do
              tr do
                th(class: "text-center") do
                  plain(:Login_name.t)
                end
                th { plain(:Full_name.t) }
                th { plain(:PROJECT_ALIASES.t) }
                th { plain(:Status.t) }
                th
              end
            end
          end

          def render_row(user)
            tr do
              render_avatar_cell(user)
              td(class: "align-middle") { plain(user.name) }
              render_aliases_cell(user)
              render_status_cell(user)
              render_edit_cell(user)
            end
          end

          def render_avatar_cell(user)
            td(class: "text-center") do
              render_user_image(user) if user.image
              user_link(user, user.login)
            end
          end

          def render_user_image(user)
            render(Components::InteractiveImage.new(
                     user: user,
                     image: user.image,
                     votes: false,
                     size: :thumbnail
                   ))
          end

          def render_aliases_cell(user)
            td(class: "align-middle") do
              render(Components::ProjectAliases.new(
                       project: @project, target: user
                     ))
            end
          end

          def render_status_cell(user)
            td(class: "align-middle") do
              plain(@project.member_status(user))
            end
          end

          def render_edit_cell(user)
            td(class: "align-middle") do
              next unless @project.is_admin?(@user)

              a(href: edit_project_member_path(
                project_id: @project.id,
                candidate: user.id
              )) do
                plain(:change_member_status_change_status.t)
              end
            end
          end
        end
      end
    end
  end
end
