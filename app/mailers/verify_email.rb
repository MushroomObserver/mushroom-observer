# Email sent to verify user's email.
class VerifyEmail < AccountMailer
  def build(user)
    setup_user(user)
    @title = :email_subject_verify.l
    debug_log(:user_question, nil, user, email: user.email)
    mo_mail(@title, to: user, from: MO.accounts_email_address)
  end
end
