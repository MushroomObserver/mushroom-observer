# User asking user about anything else.
class UserEmail < AccountMailer
  def build(sender, user, subject, content)
    setup_user(user)
    @title = subject
    @sender = sender
    @message = content || ""
    debug_log(:user_question, sender, user)
    mo_mail(@title, to: user, reply_to: sender)
  end
end
