# frozen_string_literal: true

# The user-name dropdown on the top-nav's right side, shown when
# someone is logged in. Two sections separated by a divider:
# logged-in actions (profile / preferences / etc., from
# `Tab::UserNav::LoggedIn`) and log-out actions (from
# `Tab::UserNav::LogOut`).
#
# Wraps `Components::Dropdown` — Bootstrap nav-dropdown markup,
# toggle, per-item link/button dispatch, and the auto-divider
# between sections all live there. This view just supplies the
# two Tab::Collections.
class Views::Layouts::TopNav::UserNav < Views::Base
  prop :user, ::User

  def view_template
    render(Components::Dropdown.new(
             id: "user_nav_toggle",
             menu_id: "user_drop_down",
             label: @user.login
           )) do |menu|
      menu.section(::Tab::UserNav::LoggedIn.new(user: @user))
      menu.section(::Tab::UserNav::LogOut.new(
                     user: @user, in_admin_mode: in_admin_mode?
                   ))
    end
  end
end
