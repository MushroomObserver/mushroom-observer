# frozen_string_literal: true

# Action template for `Account::LoginController#logout` — the
# "you've been logged out" landing page. Page title plus the
# textile-rendered farewell note.
module Views::Controllers::Account::Login
  class Logout < Views::FullPageBase
    def view_template
      add_page_title(:logout_title.t)
      trusted_html(:logout_note.tp)
    end
  end
end
