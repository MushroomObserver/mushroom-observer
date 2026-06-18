# frozen_string_literal: true

# Action template for `Account::VerificationsController#new` — the
# "we just sent you a verification email" landing page. Welcomes
# the new user by their legal name and emits the textile-rendered
# verification instructions. Replaces
# `app/views/controllers/account/verifications/new.html.erb`.
module Views::Controllers::Account::Verifications
  class New < Views::FullPageBase
    prop :user, ::User

    def view_template
      add_page_title(:email_welcome.t(user: @user.legal_name))
      trusted_html(:verify_note.tp(domain: MO.http_domain))
    end
  end
end
