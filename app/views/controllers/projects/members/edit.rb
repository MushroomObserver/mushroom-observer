# frozen_string_literal: true

module Views::Controllers::Projects::Members
  # Phlex view for the change member status page.
  # Replaces members/edit.html.erb.
  class Edit < Views::Base
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
      add_context_nav(Tab::Project::Members::FormEdit.new(
                        project: @project,
                        permission: permission?(@project)
                      ))

      render(Views::Controllers::Projects::Members::Form.new(
               @project_member, project: @project
             ))
      render(Views::Controllers::Projects::Members::Groups.new(
               project: @project, user: @user
             ))
    end
  end
end
