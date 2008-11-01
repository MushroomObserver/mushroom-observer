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

  DEFAULT_LOCALE = 'en-US'

  def comment(sender, receiver, object, comment)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @body["sender"]      = sender
    @body["user"]        = @user
    @body["object"]      = @object = object
    @body["comment"]     = comment
    @subject             = :email_comment_subject.l(:name => object.unique_text_name)
    @headers['Reply-To'] = sender.email if sender
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from                = NEWS_EMAIL_ADDRESS
    @content_type        = @user.html_email ? 'text/html' : 'text/plain'
  end

  def commercial_inquiry(sender, image, commercial_inquiry)
    @user                = image.user
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_commercial_inquiry_subject.l(:name => image.unique_text_name)
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
    Locale.code       = @user.locale || DEFAULT_LOCALE
    @subject          = :email_features_subject.l
    @body["user"]     = @user
    @body["features"] = features
    @recipients       = @user.email
    @bcc              = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from             = NEWS_EMAIL_ADDRESS
    @content_type     = @user.html_email ? "text/html" : "text/plain"
  end

  def naming_for_observer(observer, naming, notification)
    @user                 = observer
    Locale.code           = @user.locale || DEFAULT_LOCALE
    @subject              = :email_naming_for_observer_subject.l
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
    Locale.code       = @user.locale || DEFAULT_LOCALE
    @subject          = :email_naming_for_tracker_subject.l
    @body["user"]     = @user
    @body["naming"]   = naming
    @recipients       = @user.email
    @bcc              = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from             = NEWS_EMAIL_ADDRESS
    @content_type     = @user.html_email ? "text/html" : "text/plain"
  end

  def new_password(user, password)
    @user             = user
    Locale.code       = @user.locale || DEFAULT_LOCALE
    @subject          = :email_new_password_subject.l
    @body["password"] = password
    @body["user"]     = @user
    @recipients       = @user.email
    @bcc              = EXTRA_BCC_EMAIL_ADDRESSES
    @from             = ACCOUNTS_EMAIL_ADDRESS
    @content_type     = @user.html_email ? "text/html" : "text/plain"
  end

  def observation_question(sender, observation, question)
    @user                = observation.user
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_observation_question_subject.l(:name => observation.unique_text_name)
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
    Locale.code          = @user.locale || DEFAULT_LOCALE
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

  def admin_request(sender, project, subject, message)
    users = project.admin_group.users
    locales = users.map {|u| u.locale}.uniq.select {|c| c}
    Locale.code = locales.first if locales != []
    @subject             = subject
    @body["sender"]      = sender
    @body["message"]     = message
    @body["project"]     = project
    @recipients          = users.map() {|u| u.email }
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = "text/plain"
  end

  def verify(user)
    @user         = user
    Locale.code   = @user.locale || DEFAULT_LOCALE
    @subject      = :email_verify_subject.l
    @body["user"] = user
    @recipients   = user.email
    @bcc          = EXTRA_BCC_EMAIL_ADDRESSES
    @from         = ACCOUNTS_EMAIL_ADDRESS
    @content_type = user.html_email ? "text/html" : "text/plain"
  end

  def webmaster_question(sender, question)
    Locale.code       = DEFAULT_LOCALE
    @subject          = :email_webmaster_question_subject.l(:user => sender)
    @body["question"] = question
    @recipients       = WEBMASTER_EMAIL_ADDRESS
    @bcc	          = EXTRA_BCC_EMAIL_ADDRESSES
    @from             = sender
  end

  def denied(user_params)
    Locale.code          = DEFAULT_LOCALE
    @subject             = :email_denied_subject.l
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
