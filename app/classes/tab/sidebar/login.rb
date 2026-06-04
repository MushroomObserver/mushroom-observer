# frozen_string_literal: true

# Sidebar login link (shown when no user).
class Tab::Sidebar::Login < Tab::Base
  def title
    :app_login.t
  end

  def path
    new_account_login_path
  end

  def html_options
    { id: "nav_login_link" }
  end
end
