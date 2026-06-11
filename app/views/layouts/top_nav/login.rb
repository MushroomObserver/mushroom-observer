# frozen_string_literal: true

# The two login / signup buttons that appear on the right side of
# the top-nav when no user is logged in. Replaces the inline ERB
# partial at `app/views/controllers/application/top_nav/_login.html.erb`.
class Views::Layouts::TopNav::Login < Views::Base
  def view_template
    link_to(:app_login.t, new_account_login_path,
            class: "btn btn-sm btn-outline-default ml-3",
            id: "user_nav_login_link")
    link_to(:app_create_account.t, account_signup_path,
            class: "btn btn-sm btn-outline-default ml-3",
            id: "user_nav_signup_link")
  end
end
