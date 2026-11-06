# frozen_string_literal: true

# Renders the project members table. Rendered from the members
# index and the AddForm's turbo_stream re-render.
module Views::Controllers::Projects::Members
  class Tables < Views::Base
    prop :project, ::Project
    prop :users, _Array(::User)
    prop :user, ::User

    def view_template
      div(id: "project_members_table") do
        Table(@users.sort_by(&:login),
              variant: :striped, identifier: "project-members",
              class: "mt-3") do |table|
          define_columns(table)
        end
      end
    end

    private

    # Column class lands on BOTH `<th>` and `<td>` (current
    # Table#column behavior). An earlier version had distinct
    # th-only / td-only classes; consolidated here to a single
    # per-column class (the redundant `.align-middle` on single-line
    # thead rows is invisible in standard Bootstrap).
    def define_columns(table)
      table.column(:login_name.ti,
                   align: :center) { |u| render_avatar(u) }
      table.column(:full_name.ti, valign: :middle) { |u| plain(u.name) }
      table.column(:project_aliases.ti,
                   align: :center, valign: :middle) do |u|
        render_aliases(u)
      end
      table.column(:status.ti, valign: :middle) do |u|
        plain(member_status(u))
      end
      table.column(nil, valign: :middle) { |u| render_edit_link(u) }
    end

    # Was Project#member_status -- moved here (#4901) since its only
    # caller is this one render call site.
    def member_status(user)
      return :owner.ti if user == @project.user
      return :admin.ti if @project.is_admin?(user)
      return :member.ti if @project.member?(user)

      nil
    end

    def render_avatar(user)
      render_user_image(user) if user.image
      Link(type: :user, user: user, name: user.login)
    end

    def render_user_image(user)
      InteractiveImage(
        user: user,
        image: user.image,
        votes: false,
        size: :thumbnail
      )
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
