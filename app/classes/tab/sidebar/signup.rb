# frozen_string_literal: true

# Sidebar signup link (shown when no user).
class Tab::Sidebar::Signup < Tab::Base
  def title
    :app_create_account.t
  end

  def path
    account_signup_path
  end

  def html_options
    { id: "nav_signup_link" }
  end
end
