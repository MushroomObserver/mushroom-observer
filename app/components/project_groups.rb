# frozen_string_literal: true

# Renders member and admin group lists for a project.
# Replaces _groups.html.erb partial.
class Components::ProjectGroups < Components::Base
  def initialize(project:, user:)
    super()
    @project = project
    @user = user
  end

  def view_template
    render_group(:change_member_status_members,
                 @project.user_group.users,
                 show_edit: @project.is_admin?(@user))
    render_group(:change_member_status_admins,
                 @project.admin_group.users,
                 show_edit: @project.member?(@user))
  end

  private

  def render_group(label_key, users, show_edit:)
    p(class: "mb-0") do
      b { plain("#{label_key.t}:") }
    end
    p(class: "ml-3") do
      users.each do |u|
        render_user_row(u, show_edit)
      end
    end
  end

  def render_user_row(user, show_edit)
    user_link(user)
    if show_edit
      plain(" | ")
      a(
        href: edit_project_member_path(
          project_id: @project.id, candidate: user.id
        )
      ) { plain(:change_member_status_change_status.t) }
    end
    br
  end
end
