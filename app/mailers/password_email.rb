# frozen_string_literal: true

# User forgot their password.
class PasswordEmail < AccountMailer
  def build(user, password)
    setup_user(user)
    @title = :email_subject_new_password.l
    @password = password
    debug_log(:new_password, nil, @user)
    mo_mail(@title, to: user, from: MO.accounts_email_address)
  end
end
