#
#  Subclass of ActionMailer::Base.  It is used to send *all* email.  See also
#  these related classes:
#
#  * CommentEmail
#  * FeatureEmail
#  * QueuedEmail
#
#  Public methods:
#    email_features(...)          Mass-mailing about new features.
#    comment(...)                 Notify user of comment on their object.
#    commercial_inquiry(...)      User asking user about an image.
#    observation_question(...)    User asking user about an observation.
#    user_question(...)           User asking user about anything else.
#    webmaster_question(...)      User asking webmaster a question.
#    new_password(...)            User forgot their password.
#    verify(...)                  Email sent to verify user's email.
#    denied(...)                  Email sent to Nathan when sign-up is denied.
#
#  Private methods:
#    perform_delivery_file(mail)  Used if delivery_method is configured as :file.
#
################################################################################

class AccountMailer < ActionMailer::Base

  NEWS_EMAIL_ADDRESS        = "news@mushroomobserver.org"
  ACCOUNTS_EMAIL_ADDRESS    = "accounts@mushroomobserver.org"
  ERROR_EMAIL_ADDRESS       = "errors@mushroomobserver.org"
  WEBMASTER_EMAIL_ADDRESS   = "webmaster@mushroomobserver.org"
  EXTRA_BCC_EMAIL_ADDRESSES = "nathan@collectivesource.com"
  EXCEPTION_RECIPIENTS      = %w{webmaster@mushroomobserver.org}

  def comment(sender, receiver, object, comment)
    @user                = receiver
    @body["sender"]      = sender
    @body["user"]        = @user
    @body["object"]      = @object = object
    @body["comment"]     = comment
    @subject             = 'Comment about ' + object.unique_text_name
    if sender
      @headers['Reply-To'] = sender.email
    end
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from                = NEWS_EMAIL_ADDRESS
    @content_type        = @user.html_email ? "text/html" : "text/plain"
  end

  def commercial_inquiry(sender, image, commercial_inquiry)
    @user                = image.user
    @subject             = 'Commercial Inquiry about ' + image.unique_text_name
    @body["sender"]      = sender
    @body["image"]       = image
    @body["commercial_inquiry"] = commercial_inquiry
    @body["user"]        = @user
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = @user.html_email ? "text/html" : "text/plain"
  end

  def email_features(user, features)
    @user             = user
    @subject          = 'New Mushroom Observer Features'
    @body["user"]     = @user
    @body["features"] = features
    @recipients       = @user.email
    @bcc              = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from             = NEWS_EMAIL_ADDRESS
    @content_type     = @user.html_email ? "text/html" : "text/plain"
  end

  def naming_for_observer(observer, naming, notification)
    @user                 = observer
    @subject              = 'Mushroom Observer Research Request'
    @body["user"]         = @user
    @body["naming"]       = naming
    @body["notification"] = notification
    @recipients           = @user.email
    @bcc                  = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from                 = NEWS_EMAIL_ADDRESS
    @content_type         = @user.html_email ? "text/html" : "text/plain"
  end

  def naming_for_tracker(tracker, naming)
    @user             = tracker
    @subject          = 'Mushroom Observer Naming Notification'
    @body["user"]     = @user
    @body["naming"]   = naming
    @recipients       = @user.email
    @bcc              = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from             = NEWS_EMAIL_ADDRESS
    @content_type     = @user.html_email ? "text/html" : "text/plain"
  end
  
  def new_password(user, password)
    @user             = user
    @subject          = 'New Password for Mushroom Observer Account'
    @body["password"] = password
    @body["user"]     = @user
    @recipients       = @user.email
    @bcc              = EXTRA_BCC_EMAIL_ADDRESSES
    @from             = ACCOUNTS_EMAIL_ADDRESS
    @content_type     = @user.html_email ? "text/html" : "text/plain"
  end

  def observation_question(sender, observation, question)
    @user                = observation.user
    @subject             = 'Question about ' + observation.unique_text_name
    @body["sender"]      = sender
    @body["observation"] = observation
    @body["question"]    = question
    @body["user"]        = @user
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = @user.html_email ? "text/html" : "text/plain"
  end

  def user_question(sender, user, subject, content)
    @user                = user
    @subject             = subject
    @body["sender"]      = sender
    @body["content"]     = content
    @body["user"]        = user
    @recipients          = user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = user.html_email ? "text/html" : "text/plain"
  end

  def verify(user)
    @subject      = 'Email Verification for Mushroom Observer'
    @body["user"] = user
    @recipients   = user.email
    @bcc          = EXTRA_BCC_EMAIL_ADDRESSES
    @from         = ACCOUNTS_EMAIL_ADDRESS
    @content_type = user.html_email ? "text/html" : "text/plain"
  end

  def webmaster_question(sender, question)
    @subject          = '[MO] Question from ' + sender
    @body["question"] = question
    @recipients       = WEBMASTER_EMAIL_ADDRESS
    @bcc	          = EXTRA_BCC_EMAIL_ADDRESSES
    @from             = sender
  end

  def denied(user_params)
    @subject             = '[MO] User Creation Blocked'
    @body["user_params"] = user_params
    @recipients          = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = ACCOUNTS_EMAIL_ADDRESS
  end

  # Set delivery_method to :file to cause this method to be called whenever
  # mail is sent anywhere.  It just stuffs them all in ../mail/0001 etc.
  def perform_delivery_file(mail)
    path = '../mail'
    if File.directory?(path)
      count = 0;
      begin
        count += 1
        if count >= 10000
          raise(RangeError, "More than 10000 email files found like '#{file}'")
        end
        file = "%s/%04d" % [path, count]
      end while File.exists?(file)
      fh = File.new(file, "w")
      fh.write(mail)
      fh.close
    end
  end
end
