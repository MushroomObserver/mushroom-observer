class AccountMailer < ActionMailer::Base

  def verify(user)
    @subject      = 'Mushroom Observer Email Verification'
    @body["user"] = user
    @recipients   = user.email
    @bcc          = 'nathan@collectivesource.com'
    @from         = 'accounts@mushroomobserver.org'
  end

  def new_password(sent_at = Time.now)
    @subject    = 'AccountMailer#new_password'
    @body       = {}
    @recipients = ''
    @bcc        = 'nathan@collectivesource.com'
    @from       = ''
    @sent_on    = sent_at
    @headers    = {}
  end
end
