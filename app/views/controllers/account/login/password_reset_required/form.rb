# frozen_string_literal: true

module Views::Controllers::Account::Login
  # The one action offered on the forced-reset page: mail a reset to the
  # address on file. The login travels in a hidden field, so the person
  # at the keyboard picks neither the account nor the address.
  class PasswordResetRequired::Form < ::Components::ApplicationForm
    def view_template
      super do
        hidden_field(:login)
        submit(:login_reset_required_button.l, center: true)
      end
    end

    # `Account::PasswordResetsController#create` reads
    # `params[:new_user][:login]`.
    def key
      :new_user
    end
  end
end
