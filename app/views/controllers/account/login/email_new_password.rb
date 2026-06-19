# frozen_string_literal: true

# Action template for `Account::LoginController#email_new_password` —
# the "I forgot my password, email me a reset link" page. Page title
# plus the textile-rendered help/spam note plus the
# `EmailNewPasswordForm`.
module Views::Controllers::Account::Login
  class EmailNewPassword < Views::FullPageBase
    prop :new_user, _Nilable(::User)

    def view_template
      add_page_title(:email_new_password_title.t)
      div(class: "help-note") do
        trusted_html(:email_new_password_help.tp +
                     :email_spam_notice.tp)
      end
      render(EmailNewPasswordForm.new(
               @new_user || ::User.new,
               action: account_new_password_request_path,
               id: "account_email_new_password_form"
             ))
    end
  end
end
