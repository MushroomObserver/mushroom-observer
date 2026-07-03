# frozen_string_literal: true

module Views::Controllers::Projects::Members
  # Phlex view for the project members index page.
  class Index < Views::FullPageBase
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

      render(Views::Controllers::Projects::AdminSubtabs.new(
               project: @project, current_subtab: "members"
             ))
      render(Views::Controllers::Projects::Members::Form.new(
               @project_member, project: @project
             ))
      render_table
    end

    private

    def render_table
      Table(@users.sort_by(&:login),
            variant: :striped, identifier: "project-members",
            class: "mt-3") do |table|
        define_columns(table)
      end
    end

    # Column class lands on BOTH `<th>` and `<td>` (current
    # Table#column behavior). An earlier version had distinct
    # th-only / td-only classes; consolidated here to a single
    # per-column class (the redundant `.align-middle` on single-line
    # thead rows is invisible in standard Bootstrap).
    def define_columns(table)
      table.column(:Login_name.t,
                   class: "text-center") { |u| render_avatar(u) }
      table.column(:Full_name.t, class: "align-middle") { |u| plain(u.name) }
      table.column(:PROJECT_ALIASES.t, class: "align-middle") do |u|
        render_aliases(u)
      end
      table.column(:Status.t, class: "align-middle") do |u|
        plain(@project.member_status(u))
      end
      table.column(nil, class: "align-middle") { |u| render_edit_link(u) }
    end

    def render_avatar(user)
      render_user_image(user) if user.image
      Link(type: :user, user: user, name: user.login)
    end

    def render_user_image(user)
      render(Components::Image::Interactive.new(
               user: user,
               image: user.image,
               votes: false,
               size: :thumbnail
             ))
    end

    def render_aliases(user)
      render(Views::Controllers::Projects::Aliases::Widget.new(
               project: @project, target: user
             ))
    end

    def render_edit_link(user)
      return unless @project.is_admin?(@user)

      a(href: edit_project_member_path(
        project_id: @project.id,
        candidate: user.id
      )) do
        plain(:change_member_status_change_status.t)
      end
    end
  end
end
