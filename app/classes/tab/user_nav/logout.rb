# frozen_string_literal: true

# "Logout" link in the user-nav dropdown.
class Tab::UserNav::Logout < Tab::Base
  def title
    :app_logout.l
  end

  def path
    account_logout_path
  end

  def html_options
    { id: "user_nav_logout_link", button: :post }
  end
end
