# frozen_string_literal: true

# Action template for `Account::PasswordResetsController#new` — the
# "I forgot my password, email me a reset link" page. Page title
# plus the textile-rendered help/spam note plus the `Form`.
module Views::Controllers::Account::PasswordResets
  class New < Views::FullPageBase
    prop :new_user, _Nilable(::User)

    def view_template
      add_page_title(:email_new_password_title.t)

      Help(content: help_text)
      render(Form.new(
               @new_user || ::User.new,
               action: account_password_reset_path,
               id: "account_password_reset_form"
             ))
    end

    private

    def help_text
      capture do
        trusted_html(:email_new_password_help.tp)
        br
        trusted_html(:email_spam_notice.tp)
      end
    end
  end
end
