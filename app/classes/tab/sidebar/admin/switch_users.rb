# frozen_string_literal: true

# Sidebar admin nav: switch-users page.
class Tab::Sidebar::Admin::SwitchUsers < Tab::Base
  def title
    :app_switch_users.t
  end

  def path
    edit_admin_mode_path
  end
end
