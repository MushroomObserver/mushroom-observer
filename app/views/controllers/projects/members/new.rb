# frozen_string_literal: true

module Views::Controllers::Projects::Members
  # Phlex view for the add members page.
  class New < Views::FullPageBase
    def initialize(project:, users:, project_member:, user:)
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
      add_context_nav(Tab::Project::Members::FormNew.new(project: @project))
      container_class(:wide)

      render(Views::Controllers::Projects::Members::Form.new(
               @project_member, project: @project
             ))
      render_users_table
    end

    private

    def render_users_table
      Table(@users.sort_by(&:login),
            variant: :striped, identifier: "project-members",
            class: "mt-3") do |t|
        t.column(:login_name.ti) do |u|
          Link(type: :user, user: u, name: u.login)
        end
        t.column(:full_name.ti) { |u| plain(u.name) }
        t.column(nil) { |u| render_add_button(u) }
      end
    end

    def render_add_button(user)
      Button(
        type: :post,
        variant: :strip,
        name: :add.ti,
        target: project_members_path(
          project_id: @project.id,
          candidate: user.id
        )
      )
    end
  end
end
