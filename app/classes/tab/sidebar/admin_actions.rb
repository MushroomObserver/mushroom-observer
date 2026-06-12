# frozen_string_literal: true

# Sidebar admin section — shown only when `in_admin_mode?`.
class Tab::Sidebar::AdminActions < Tab::Collection
  private

  def tabs
    [Tab::Sidebar::Admin::Jobs.new,
     Tab::Sidebar::Admin::BlockedIps.new,
     Tab::Sidebar::Admin::SwitchUsers.new,
     Tab::Sidebar::Admin::Users.new,
     Tab::Sidebar::Admin::Banners.new,
     Tab::Sidebar::Admin::Licenses.new]
  end
end
