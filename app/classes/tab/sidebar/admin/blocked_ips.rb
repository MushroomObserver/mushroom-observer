# frozen_string_literal: true

# Sidebar admin nav: blocked-IPs page.
class Tab::Sidebar::Admin::BlockedIps < Tab::Base
  def title
    :app_blocked_ips.t
  end

  def path
    edit_admin_blocked_ips_path
  end
end
