#
#  Subclass of ActionMailer::Base.  It is used to send all email.  See also
#  QueuedEmail for more information about how queuing works and how all the
#  email-related classes and subclasses are related.
#
#  Public methods:
#    comment(...)                 Notify user of comment on their object.
#    commercial_inquiry(...)      User asking user about an image.
#    consensus_change(...)        Notify user of name change of their obs.
#    denied(...)                  Email sent to Nathan when sign-up is denied.
#    email_features(...)          Mass-mailing about new features.
#    name_change(...)             Notify user of change in name description.
#    name_proposal(...)           Notify user of name proposal for their obs.
#    new_password(...)            User forgot their password.
#    observation_change(...)      Notify user of change in observation.
#    observation_question(...)    User asking user about an observation.
#    user_question(...)           User asking user about anything else.
#    verify(...)                  Email sent to verify user's email.
#    webmaster_question(...)      User asking webmaster a question.
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

  # Note: privacy policy is currently that a user's email address is only
  # revealed to people they explicitly send questions to, or to the owner
  # of the observation they comment on.  NOT to third parties who are simply
  # interested in or who have also commented on the same observation.

  def comment(sender, receiver, object, comment)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @body["sender"]      = sender
    @body["user"]        = @user
    @body["object"]      = object
    @body["comment"]     = comment
    @subject             = :email_comment_subject.l(:name => object.unique_text_name)
    @headers['Reply-To'] = sender.email if sender && receiver == object.user
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from                = NEWS_EMAIL_ADDRESS
    @content_type        = @user.html_email ? 'text/html' : 'text/plain'
  end

  def name_proposal(sender, receiver, naming, observation)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @body["user"]        = @user
    @body["naming"]      = naming
    @body["observation"] = observation
    @subject             = :email_name_proposal_subject.l(:name => naming.text_name, :id => observation.id)
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from                = NEWS_EMAIL_ADDRESS
    @content_type        = @user.html_email ? 'text/html' : 'text/plain'
  end

  def consensus_change(sender, receiver, observation, old_name, new_name, time)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @body["sender"]      = sender
    @body["user"]        = @user
    @body["observation"] = observation
    @body["old_name"]    = old_name
    @body["new_name"]    = new_name
    @body["time"]        = time
    @subject             = :email_consensus_change_subject.l(:id => observation.id,
                                :old => (old_name ? old_name.search_name : 'none'),
                                :new => (new_name ? new_name.search_name : 'none'))
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from                = NEWS_EMAIL_ADDRESS
    @content_type        = @user.html_email ? 'text/html' : 'text/plain'
  end

  def observation_change(sender, receiver, observation, note, time)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @body["sender"]      = sender
    @body["user"]        = @user
    @body["observation"] = observation
    @body["note"]        = note
    @body["time"]        = time
    @subject             = observation ? :email_observation_change_subject.l(:name => observation.unique_text_name) :
                                         :email_observation_destroy_subject.l(:name => note).t.html_to_ascii
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from                = NEWS_EMAIL_ADDRESS
    @content_type        = @user.html_email ? 'text/html' : 'text/plain'
  end

  def name_change(sender, receiver, time, name, old_version, new_version, review_status)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @body["user"]        = @user
    @body["sender"]      = sender
    @body["time"]        = time
    @body["name"]        = name
    @body["old_name"]    = old_name = name.versions.find_by_version(old_version)
    @body["new_name"]    = new_name = name.versions.find_by_version(new_version)
    @body["review_status"] = review_status
    @subject             = :email_name_change_subject.l(:name => old_name.search_name)
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

  def publish_name(publisher, receiver, name)
    @user                 = receiver
    @name                 = name
    Locale.code           = @user.locale || DEFAULT_LOCALE
    @subject              = :email_publish_name_subject.l
    @body["publisher"]    = publisher
    @body["user"]         = receiver
    @body["name"]         = name
    @recipients           = receiver.email
    @bcc                  = EXTRA_BCC_EMAIL_ADDRESSES unless QUEUE_EMAIL
    @from                 = NEWS_EMAIL_ADDRESS
    @content_type         = @user.html_email ? "text/html" : "text/plain"
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
    # @content_type         = @user.html_email ? "text/html" : "text/plain"
    @content_type         = "text/plain"
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

  def author_request(sender, name, subject, message)
    users = name.authors + UserGroup.find_by_name('reviewers').users
    locales = users.map {|u| u.locale}.uniq.select {|c| c}
    Locale.code = locales.first if locales != []
    @subject             = subject
    @body["sender"]      = sender
    @body["message"]     = message
    @body["name"]        = name
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
