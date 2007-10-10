class AccountMailer < ActionMailer::Base

  NEWS_EMAIL_ADDRESS        = "news@mushroomobserver.org"
  ACCOUNTS_EMAIL_ADDRESS    = "accounts@mushroomobserver.org"
  ERROR_EMAIL_ADDRESS       = "errors@mushroomobserver.org"
  WEBMASTER_EMAIL_ADDRESS   = "webmaster@mushroomobserver.org"
  EXTRA_BCC_EMAIL_ADDRESSES = "nathan@collectivesource.com"
  EXCEPTION_RECIPIENTS      = %w{webmaster@mushroomobserver.org}

  def comment(sender, observation, comment)
    user                 = observation.user
    @body["sender"]      = sender
    @body["user"]        = user
    @body["observation"] = observation
    @body["comment"]     = comment
    @subject             = 'Comment about ' + observation.unique_text_name
    @headers['Reply-To'] = sender.email
    @recipients          = user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @content_type        = user.html_email ? "text/html" : "text/plain"
  end

  def commercial_inquiry(sender, image, commercial_inquiry)
    @subject             = 'Commercial Inquiry about ' + image.unique_text_name
    @body["sender"]      = sender
    @body["image"]       = image
    @body["commercial_inquiry"] = commercial_inquiry
    user                 = image.user
    @body["user"]        = user
    @recipients          = user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = user.html_email ? "text/html" : "text/plain"
  end

  def email_features(user, features)
    @subject          = 'New Mushroom Observer Features'
    @body["user"]     = user
    @body["features"] = features
    @recipients       = user.email
    @bcc              = EXTRA_BCC_EMAIL_ADDRESSES
    @from             = NEWS_EMAIL_ADDRESS
    @content_type     = user.html_email ? "text/html" : "text/plain"
  end

  def new_password(user, password)
    @subject          = 'New Password for Mushroom Observer Account'
    @body["password"] = password
    @body["user"]     = user
    @recipients       = user.email
    @bcc              = EXTRA_BCC_EMAIL_ADDRESSES
    @from             = ACCOUNTS_EMAIL_ADDRESS
    @content_type     = user.html_email ? "text/html" : "text/plain"
  end

  def question(sender, observation, question)
    @subject             = 'Question about ' + observation.unique_text_name
    @body["sender"]      = sender
    @body["observation"] = observation
    @body["question"]    = question
    user                 = observation.user
    @body["user"]        = user
    @recipients          = user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = user.html_email ? "text/html" : "text/plain"
  end

  def verify(user)
    @subject      = 'Mushroom Observer Email Verification'
    @body["user"] = user
    @recipients   = user.email
    @bcc          = EXTRA_BCC_EMAIL_ADDRESSES
    @from         = ACCOUNTS_EMAIL_ADDRESS
    @content_type = user.html_email ? "text/html" : "text/plain"
  end

  def webmaster_question(sender, question)
    @subject          = 'Mushroom Observer Question from ' + sender
    @body["question"] = question
    @recipients       = WEBMASTER_EMAIL_ADDRESS
    @bcc	          = EXTRA_BCC_EMAIL_ADDRESSES
    @from             = sender
  end

  def denied(user_params)
    @subject             = 'Mushroom Observer User Creation Blocked'
    @body["user_params"] = user_params
    @recipients          = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = ACCOUNTS_EMAIL_ADDRESS
  end
end
