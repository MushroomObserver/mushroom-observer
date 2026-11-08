# frozen_string_literal: true

# Action template rendered by `Account::LoginController#create` when the
# submitted password is correct but the account is flagged for a reset.
# Grants no session: the single action available is a button asking for
# a reset email, which reaches the address on file rather than whoever
# is at the keyboard.
module Views::Controllers::Account::Login
  class PasswordResetRequired < Views::FullPageBase
    prop :flagged_user, ::User

    def view_template
      add_page_title(:login_reset_required_title.t)
      Alert(level: :warning, id: "password_reset_required_notice") do
        trusted_html(
          :login_reset_required_explanation.t(
            email: @flagged_user.masked_email
          )
        )
      end
      # An unsaved User, so Superform posts to #create rather than
      # picking PATCH off a persisted record.
      render(Views::Controllers::Account::Login::PasswordResetRequired::
             Form.new(
               ::User.new(login: @flagged_user.login),
               action: account_password_reset_path,
               id: "password_reset_required_form"
             ))
    end
  end
end
