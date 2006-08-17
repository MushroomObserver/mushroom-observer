class AccountMailer < ActionMailer::Base

  def verify(user)
    @subject      = 'Mushroom Observer Email Verification'
    @body["user"] = user
    @recipients   = user.email
    @bcc          = 'nathan@collectivesource.com'
    @from         = 'accounts@mushroomobserver.org'
  end

  def new_password(user, password)
    @subject    = 'New Password for Mushroom Observer Account'
    @body["password"] = password
    @recipients = user.email
    @bcc        = 'nathan@collectivesource.com'
    @from       = 'accounts@mushroomobserver.org'
  end
end
