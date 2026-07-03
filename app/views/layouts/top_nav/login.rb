# frozen_string_literal: true

# The two login / signup buttons that appear on the right side of
# the top-nav when no user is logged in.
class Views::Layouts::TopNav::Login < Views::Base
  def view_template
    Button(
      type: :get,
      name: :app_login.t,
      target: new_account_login_path,
      variant: :outline, size: :sm,
      class: "ml-3",
      id: "user_nav_login_link"
    )
    Button(
      type: :get,
      name: :app_create_account.t,
      target: account_signup_path,
      variant: :outline, size: :sm,
      class: "ml-3",
      id: "user_nav_signup_link"
    )
  end
end
