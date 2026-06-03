# frozen_string_literal: true

# Sidebar admin nav: users-by-name index.
class Tab::Sidebar::Admin::Users < Tab::Base
  def title
    :app_users.t
  end

  def path
    users_path(by: "name")
  end

  def html_options
    { id: "nav_admin_user_index_link" }
  end
end
