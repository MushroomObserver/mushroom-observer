class AccountMailer < ActionMailer::Base

  def commercial_inquiry(sender, image, commercial_inquiry)
    @subject    = 'Commercial Inquiry About ' + image.unique_name
    @body["sender"] = sender
    @body["image"] = image
    @body["commercial_inquiry"] = commercial_inquiry
    user = image.user
    @body["user"] = user
    @recipients = user.email
    @bcc        = 'nathan@collectivesource.com'
    @from       = 'news@mushroomobserver.org'
    @headers['Reply-To'] = sender.email
  end

  def email_features(user, features)
    @subject    = 'New Mushroom Observer Features'
    @body["user"] = user
    @body["features"] = features
    @recipients = user.email
    @bcc        = 'nathan@collectivesource.com'
    @from       = 'news@mushroomobserver.org'
  end

  def new_password(user, password)
    @subject    = 'New Password for Mushroom Observer Account'
    @body["password"] = password
    @recipients = user.email
    @bcc        = 'nathan@collectivesource.com'
    @from       = 'accounts@mushroomobserver.org'
  end

  def question(sender, observation, question)
    @subject    = 'Question About ' + observation.unique_name
    @body["sender"] = sender
    @body["observation"] = observation
    @body["question"] = question
    user = observation.user
    @body["user"] = user
    @recipients = user.email
    @bcc        = 'nathan@collectivesource.com'
    @from       = 'news@mushroomobserver.org'
    @headers['Reply-To'] = sender.email
  end

  def verify(user)
    @subject      = 'Mushroom Observer Email Verification'
    @body["user"] = user
    @recipients   = user.email
    @bcc          = 'nathan@collectivesource.com'
    @from         = 'accounts@mushroomobserver.org'
  end
end
