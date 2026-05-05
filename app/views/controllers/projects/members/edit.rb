# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module Members
        # Phlex view for the change member status page.
        # Replaces members/edit.html.erb.
        class Edit < Views::Base
          register_output_helper :add_page_title
          register_output_helper :add_context_nav
          register_value_helper :project_member_form_edit_tabs

          def initialize(project:, project_member:, user:)
            super()
            @project = project
            @project_member = project_member
            @user = user
          end

          def view_template
            add_page_title(
              :change_member_status_title.t(
                name: @project_member.user.legal_name,
                title: @project.title
              )
            )
            add_context_nav(
              project_member_form_edit_tabs(
                project: @project
              )
            )

            render(Components::ProjectMemberForm.new(
                     @project_member, project: @project
                   ))
            render(Components::ProjectGroups.new(
                     project: @project, user: @user
                   ))
          end
        end
      end
    end
  end
end
