# encoding: utf-8
#
#  = Email Handler
#
#  This class is used to send all email.  Note that it is just a collection of
#  class methods; it is never instantiated.  It is a subclass of
#  ActionMailer::Base.  See also QueuedEmail for more information about how
#  queuing works and how all the email-related classes and subclasses are
#  related.
#
#  == Class methods
#
#  admin_request::          Ask project admins for admin privileges on project.
#  author_request::         Ask reviewers for authorship credit.
#  comment::                Notify user of comment on their object.
#  commercial_inquiry::     User asking user about an image.
#  consensus_change::       Notify user of name change of their obs.
#  denied::                 Email sent to Nathan when sign-up is denied.
#  email_features::         Mass-mailing about new features.
#  email_registration::     Verify a conference event registration.
#  location_change::        Notify user of change in location description.
#  name_change::            Notify user of change in name description.
#  name_proposal::          Notify user of name proposal for their obs.
#  naming_for_observer::    Tell observer someone is interested in their obs.
#  naming_for_tracker::     Notify user someone has observed a name they are interested in.
#  new_password::           User forgot their password.
#  observation_change::     Notify user of change in observation.
#  observation_question::   User asking user about an observation.
#  publish_name::           Notify reviewers that a draft has been published.
#  user_question::          User asking user about anything else.
#  verify::                 Email sent to verify user's email.
#  webmaster_question::     User asking webmaster a question.
#
#  == Delivery methods
#
#  There are four delivery methods available, configurable in
#  config/environment.rb as:
#
#    config.action_mailer.delivery_method = :method
#
#  Where <tt>:method</tt> is one of these:
#
#  smtp::      Default for production: uses the Net::SMTP ruby library.
#  sendmail::  We've never used this: uses <tt>/usr/sbin/sendmail</tt>.
#  test::      Default for unit tests: ???
#  file::      Default for development: writes emails as files in
#                <tt>RAILS_ROOT/../mail</tt> (if this directory exists).
#
#  == Privacy policy
#
#  Our current policy is that a user's email address is only revealed to people
#  they explicitly send questions to, or to the owner of the observation they
#  comment on. *NOT* to third parties who are simply interested in or who have
#  also commented on the same observation.
#
################################################################################

require 'smtp_tls'

class AccountMailer < ActionMailer::Base

  # Ask project admins for admin privileges on project.
  # sender::    User asking for permission.
  # receiver::  Admin user.
  # project::   Project instance.
  # subject::   Subject of message (provided by user?).
  # message::   Content of message (provided by user).
  def admin_request(sender, receiver, project, subject, message)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = subject
    @body['subject']     = @subject
    @body['user']        = @user
    @body['sender']      = sender
    @body['message']     = message || ''
    @body['project']     = project
    @recipients          = receiver.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = @user.email_html ? 'text/html' : 'text/plain'
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL admin_request " +
                          "from=#{sender.id} " +
                          "to=#{receiver.id} " +
                          "project=#{project.id}")
  end

  # Ask reviewers for authorship credit.
  # sender::    User asking for credit.
  # receiver::  Reviewer/admin user.
  # object::    NameDescription or LocationDescription on which User would like to be author.
  # subject::   Subject of message (provided by user?).
  # message::   Content of message (provided by user).
  def author_request(sender, receiver, object, subject, message)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = subject
    @body['subject']     = @subject
    @body['user']        = @user
    @body['sender']      = sender
    @body['message']     = message || ''
    @body['object']      = object
    @recipients          = receiver.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = @user.email_html ? 'text/html' : 'text/plain'
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL author_request " +
                          "from=#{sender.id} " +
                          "to=#{receiver.id} " +
                          "object=#{object.type_tag}-#{object.id}")
  end

  # Notify user of comment on their object.
  # sender::    User who posted the Comment.
  # receiver::  Owner of target (or interested party).
  # target::    Object that was commented upon.
  # comment::   Comment that triggered this email.
  def comment(sender, receiver, target, comment)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_comment.l(:name => target.unique_text_name)
    @body['subject']     = @subject
    @body['user']        = @user
    @body['sender']      = sender
    @body['target']      = target
    @body['comment']     = comment
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = (sender && receiver == target.user) ? sender.email : NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? 'text/html' : 'text/plain'
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL comment " +
                          "from=#{sender.id} " +
                          "to=#{receiver.id} " +
                          "object=#{target.type_tag}-#{target.id}")
  end

  # User asking user about an image.
  # sender::             User asking the question.
  # image::              Image in question.
  # commercial_inquiry:: Content of message (provided by user).
  def commercial_inquiry(sender, image, commercial_inquiry)
    @user                = image.user
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_commercial_inquiry.l(:name => image.unique_text_name)
    @body['subject']     = @subject
    @body['user']        = @user
    @body['sender']      = sender
    @body['image']       = image
    @body['message']     = commercial_inquiry || ''
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = @user.email_html ? "text/html" : "text/plain"
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL commercial_inquiry " +
                          "from=#{sender.id} " +
                          "to=#{image.user_id} " +
                          "image=#{image.id}")
  end

  # Notify user of name change of their obs.
  # sender::        User who voted or proposed the name that caused the change.
  # receiver::      Owner of the Observation (or interested third party).
  # observation::   Observation in question.
  # old_name::      Old consensus Name.
  # new_name::      New consensus Name.
  # time::          Time the change took place.
  def consensus_change(sender, receiver, observation, old_name, new_name, time)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_consensus_change.l(:id => observation.id,
                                :old => (old_name ? old_name.real_search_name : 'none'),
                                :new => (new_name ? new_name.real_search_name : 'none'))
    @body['subject']     = @subject
    @body['user']        = @user
    @body['sender']      = sender
    @body['observation'] = observation
    @body['old_name']    = old_name
    @body['new_name']    = new_name
    @body['time']        = time
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? 'text/html' : 'text/plain'
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL consensus_change " +
                          "from=#{sender.id} " +
                          "to=#{receiver.id} " +
                          "observation=#{observation.id}")
  end

  # Email sent to Nathan when sign-up is denied.
  # user_params::   Hash of parameters from form.
  def denied(user_params)
    Locale.code          = DEFAULT_LOCALE
    @subject             = :email_subject_denied.l
    @body['subject']     = @subject
    @body['user']        = @user
    @body['user_params'] = user_params
    @recipients          = WEBMASTER_EMAIL_ADDRESS
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = ACCOUNTS_EMAIL_ADDRESS
    @subject             = '[MO] ' + @subject.to_ascii
  end

  # Mass-mailing about new features.
  # user::      User we're sending announcement to.
  # features::  Description of changes (body of email).
  def email_features(user, features)
    @user                = user
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_features.l
    @body['subject']     = @subject
    @body['user']        = @user
    @body['features']    = features
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? "text/html" : "text/plain"
    @subject             = '[MO] ' + @subject.to_ascii
  end

  # Notify email given in registration of the registration
  # user::         User we're sending announcment to.  Defaults to admin.
  # registration:: ConferenceRegistration object
  def email_registration(user, registration)
    event = registration.conference_event
    @user                = user
    Locale.code          = DEFAULT_LOCALE
    Locale.code          = @user.locale if @user and @user.locale
    @subject             = :email_subject_registration.l(:name => event.name)
    @body['registration'] = registration
    @body['subject']     = @subject
    @body['user']        = user
    @recipients          = registration.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = WEBMASTER_EMAIL_ADDRESS
    @content_type        = 'text/html'
    @content_type        = 'text/plain' if @user and not @user.email_html
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL registration " +
                          "to=#{registration.email} ")
  end

  # Notify user of change in location description.
  # sender::        User who changed the Location.
  # receiver::      Owner of the Location (or interested third party).
  # time::          Time the change took place.
  # loc::           Location in question.
  # desc::          LocationDescription in question.
  # old_loc_ver::   Version number of the Location _before_ the change.
  # new_loc_ver::   Version number of the Location _after_ the change (may be the same).
  # old_desc_ver::  Version number of the LocationDescription _before_ the change.
  # new_desc_ver::  Version number of the LocationDescription _after_ the change (may be the same).
  def location_change(sender, receiver, time, loc, desc, old_loc_version,
                      new_loc_version, old_desc_version, new_desc_version)
    old_loc              = loc.revert_clone(old_loc_version)
    new_loc              = loc.revert_clone(new_loc_version)
    if desc
      old_desc           = desc.revert_clone(old_desc_version)
      new_desc           = desc.revert_clone(new_desc_version)
    else
      old_desc           = nil
      new_desc           = nil
    end
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_location_change.l(:name => old_loc.display_name)
    @body['subject']     = @subject
    @body['user']        = @user
    @body['sender']      = sender
    @body['time']        = time
    @body['old_loc']     = old_loc
    @body['new_loc']     = new_loc
    @body['old_desc']    = old_desc
    @body['new_desc']    = new_desc
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? 'text/html' : 'text/plain'
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL location_change " +
                          "from=#{sender.id} " +
                          "to=#{receiver.id} " +
                          "location=#{loc.id rescue 'nil'} " +
                          "description=#{desc.id rescue 'nil'}")
  end

  # Notify user of change in name description.
  # sender::        User who changed the Name.
  # receiver::      Owner of the Name (or interested third party).
  # time::          Time the change took place.
  # name::          Name in question.
  # desc::          NameDescription in question.
  # old_name_ver::  Version number of the Name _before_ the change.
  # new_name_ver::  Version number of the Name _after_ the change (may be the same).
  # old_desc_ver::  Version number of the NameDescription _before_ the change.
  # new_desc_ver::  Version number of the NameDescription _after_ the change (may be the same).
  # review_status:: Current review status.
  def name_change(sender, receiver, time, name, desc, old_name_version,
          new_name_version, old_desc_version, new_desc_version, review_status)
    old_name             = name.revert_clone(old_name_version)
    new_name             = name.revert_clone(new_name_version)
    if desc 
      old_desc           = desc.revert_clone(old_desc_version)
      new_desc           = desc.revert_clone(new_desc_version)
    else
      old_desc           = nil
      new_desc           = nil
    end
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_name_change.l(:name =>
                              (old_name ? old_name.real_search_name : new_name.real_search_name))
    @body['subject']     = @subject
    @body['user']        = @user
    @body['sender']      = sender
    @body['time']        = time
    @body['old_name']    = old_name
    @body['new_name']    = new_name
    @body['old_desc']    = old_desc
    @body['new_desc']    = new_desc
    @body['review_status'] = "review_#{review_status}".to_sym.l if review_status != :no_change
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? 'text/html' : 'text/plain'
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL name_change " +
                          "from=#{sender.id} " +
                          "to=#{receiver.id} " +
                          "name=#{name.id rescue 'nil'} " +
                          "description=#{desc.id rescue 'nil'}")
  end

  # Notify user of name proposal for their obs.
  # sender::        User who proposed the Name.
  # receiver::      Owner of the Observation (or interested third party).
  # naming::        Naming in question.
  # observation::   Observation in question.
  def name_proposal(sender, receiver, naming, observation)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_name_proposal.l(:name => naming.text_name,
                                                          :id => observation.id)
    @body['subject']     = @subject
    @body['user']        = @user
    @body['naming']      = naming
    @body['observation'] = observation
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? 'text/html' : 'text/plain'
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL name_proposal " +
                          "from=#{sender.id} " +
                          "to=#{receiver.id} " +
                          "naming=#{naming.id rescue 'nil'} " +
                          "observation=#{observation.id rescue 'nil'}")
  end

  # Tell observer someone is interested in their obs.
  # observer::      Owner of the Observation.
  # naming::        Naming that was proposed that triggered this email.
  # notification::  Notification instance registering interest in this Name.
  def naming_for_observer(observer, naming, notification)
    sender               = notification.user
    @user                = observer
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_naming_for_observer.l
    @body['subject']     = @subject
    @body['user']        = @user
    @body['naming']      = naming
    @body['notification'] = notification
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender ? sender.email : NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? "text/html" : "text/plain"
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL naming_for_observer " +
                          "from=#{sender.id rescue 'nil'} " +
                          "to=#{@user.id rescue 'nil'} " +
                          "naming=#{naming.id rescue 'nil'} " +
                          "notification=#{notification.id rescue 'nil'}")
  end

  # Notify user someone has observed a name they are interested in.
  # tracker::   User that has created the Notification registering interest in this Name.
  # naming::    Naming that triggered this email.
  def naming_for_tracker(tracker, naming)
    @user                = tracker
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_naming_for_tracker.l
    @body['subject']     = @subject
    @body['user']        = @user
    @body['observation'] = naming.observation
    @body['naming']      = naming
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? "text/html" : "text/plain"
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL naming_for_tracker " +
                          "from=#{'nil'} " +
                          "to=#{@user.id rescue 'nil'} " +
                          "naming=#{naming.id rescue 'nil'} " +
                          "observation=#{naming.observation.id rescue 'nil'}")
  end

  # User forgot their password.
  # user::      User who requested the new password.
  # password::  The new password (unencrypted).
  def new_password(user, password)
    @user                = user
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_new_password.l
    @body['subject']     = @subject
    @body['user']        = @user
    @body['password']    = password
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = ACCOUNTS_EMAIL_ADDRESS
    @headers['Reply-To'] = NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? "text/html" : "text/plain"
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL new_password " +
                          "to=#{@user.id rescue 'nil'}")
  end

  # Notify user of change in observation.
  # sender::        User who changed the Observation (should be the owner).
  # receiver::      Third party user who is interested in this Observation.
  # observation::   Observation in question.
  # note::          List of changed attributes (see QueuedEmail::ObservationChange).
  # time::          Time the change took place.
  def observation_change(sender, receiver, observation, note, time)
    @user                = receiver
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = observation ? :email_subject_observation_change.l(:name => observation.unique_text_name) :
                                         :email_subject_observation_destroy.l(:name => note).t.html_to_ascii
    @body['subject']     = @subject
    @body['user']        = @user
    @body['sender']      = sender
    @body['observation'] = observation
    @body['note']        = note
    @body['time']        = time
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? 'text/html' : 'text/plain'
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL observation_change " +
                          "from=#{sender.id} " +
                          "to=#{receiver.id} " +
                          "observation=#{observation.id rescue 'nil'}")
  end

  # User asking user about an observation.
  # sender::        User asking the question.
  # observation::   Observation the question is about.
  # question::      The actual question (content).
  def observation_question(sender, observation, question)
    @user                = observation.user
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_observation_question.l(:name => observation.unique_text_name)
    @body['subject']     = @subject
    @body['user']        = @user
    @body['sender']      = sender
    @body['observation'] = observation
    @body['message']     = question || ''
    @recipients          = @user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = @user.email_html ? "text/html" : "text/plain"
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL observation_question " +
                          "from=#{sender.id rescue 'nil'} " +
                          "to=#{@user.id rescue 'nil'} " +
                          "observation=#{observation.id rescue nil}")
  end

  # Notify reviewers that a draft has been published.
  # publisher:: User who is publishing the draft.
  # receiver::  Reviewer receiving the announcement.
  # name::      Name whose description is being published.
  def publish_name(publisher, receiver, name)
    @user                = receiver
    @name                = name
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_publish_name.l
    @body['subject']     = @subject
    @body['user']        = receiver
    @body['publisher']   = publisher
    @body['name']        = name
    @recipients          = receiver.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = NOREPLY_EMAIL_ADDRESS
    @content_type        = @user.email_html ? "text/html" : "text/plain"
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL publish_name " +
                          "from=#{publisher.id rescue 'nil'} " +
                          "to=#{receiver.id rescue 'nil'} " +
                          "name=#{name.id rescue nil}")
  end

  # Notify email given in registration of a change in the registration
  # user::         User we're sending announcment to.  Defaults to admin.
  # before::       String describing the registration before the change.
  # after::        String describing the registration after the change.
  def update_registration(user, registration, before)
    event = registration.conference_event
    @user                = user
    Locale.code          = DEFAULT_LOCALE
    Locale.code          = @user.locale if @user and @user.locale
    @subject             = :email_subject_update_registration.l(:name => event.name)
    @body['registration'] = registration
    @body['before']      = before
    @body['subject']     = @subject
    @body['user']        = user
    @recipients          = registration.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = WEBMASTER_EMAIL_ADDRESS
    @content_type        = 'text/html'
    @content_type        = 'text/plain' if @user and not @user.email_html
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL update_registration " +
                          "to=#{registration.email} ")
  end

  # User asking user about anything else.
  # sender::    User asking the question.
  # user::      User receiving the question.
  # subject::   Subject of question (provided by user).
  # content::   Content of question (provided by user).
  def user_question(sender, user, subject, content)
    @user                = user
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = subject
    @body['subject']     = @subject
    @body['user']        = user
    @body['sender']      = sender
    @body['message']     = content || ''
    @recipients          = user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = NEWS_EMAIL_ADDRESS
    @headers['Reply-To'] = sender.email
    @content_type        = @user.email_html ? "text/html" : "text/plain"
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL user_question " +
                          "from=#{sender.id rescue 'nil'} " +
                          "to=#{user.id rescue 'nil'}")
  end

  # Email sent to verify user's email.
  # user::      User that just signed up.
  def verify(user)
    @user                = user
    Locale.code          = @user.locale || DEFAULT_LOCALE
    @subject             = :email_subject_verify.l
    @body['subject']     = @subject
    @body['user']        = user
    @recipients          = user.email
    @bcc                 = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = ACCOUNTS_EMAIL_ADDRESS
    @content_type        = @user.email_html ? "text/html" : "text/plain"
    @subject             = '[MO] ' + @subject.to_ascii
    QueuedEmail.debug_log("MAIL verify " +
                          "to=#{user.id} email=#{user.email}")
  end

  # User asking webmaster a question.
  # sender::    User asking the question.
  # question::  Content of the question.
  def webmaster_question(sender, question)
    Locale.code          = DEFAULT_LOCALE
    @subject             = :email_subject_webmaster_question.l(:user => sender)
    @body['question']    = question
    @recipients          = WEBMASTER_EMAIL_ADDRESS
    @bcc	               = EXTRA_BCC_EMAIL_ADDRESSES
    @from                = WEBMASTER_EMAIL_ADDRESS
    @headers['Reply-To'] = sender
    @subject             = '[MO] ' + @subject.to_ascii
  end

################################################################################

private

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

  # Log exactly who is sending email at what times.
  # def log_email
  #   File.open("#{RAILS_ROOT}/log/email-low-level.log", 'a:utf-8') do |fh|
  #     time = Time.now.strftime('%Y-%m-%d:%H:%M:%S')
  #
  #     begin
  #       raise RuntimeError
  #     rescue RuntimeError => e
  #       trace = e.backtrace
  #     rescue
  #       trace = []
  #     end
  #
  #     type = trace[3].match(/`(\w+)'/) ? $1 : 'nil'
  #
  #     caller = nil
  #     for x in trace[4..-1]
  #       if !x.match(/^\/usr/)
  #         caller = x
  #         break
  #       end
  #     end
  #
  #     fh.puts("time=#{time} cmd=#{$0.inspect} type=#{type.inspect} " +
  #             "caller=#{caller.inspect}")
  #   end
  # end
end
