# frozen_string_literal: true

# Action template for `Account::LoginController#test_autologin` — a
# blank "you hit the autologin test page" stub used by the manual
# autologin flow check. Replaces
# `app/views/controllers/account/login/test_autologin.html.erb`.
module Views::Controllers::Account::Login
  class TestAutologin < Views::FullPageBase
    def view_template
      p { plain("This page is used to test the autologin feature.") }
    end
  end
end
