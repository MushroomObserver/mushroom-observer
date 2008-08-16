require File.dirname(__FILE__) + '/../test_helper'
require 'account_mailer'

class AccountMailerTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"
  fixtures :users
  fixtures :images
  fixtures :observations
  fixtures :names
  fixtures :namings
  fixtures :comments
  fixtures :notifications

  include ActionMailer::Quoting

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.mime_version = '1.0'
  end

  def test_comment
    @expected.body = read_fixture('comment_inquiry')
    @expected.subject = 'Comment about ' + @detailed_unknown.unique_text_name

    @expected.to = @detailed_unknown.user.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'news@mushroomobserver.org'
    @expected.reply_to = @mary.email
    @expected.content_type = "text/html"
    @expected.set_content_type "text", "html", { "charset" => CHARSET }

    # comment(sender, observation, comment)
    account_mailer = AccountMailer.create_comment(@mary, @detailed_unknown.user, @detailed_unknown,
      @minimal_comment)
    assert_equal @expected.encoded, account_mailer.encoded
  end

  def test_commercial_inquiry
    @expected.body = read_fixture('commercial_inquiry')
    @expected.subject = 'Commercial Inquiry about ' + @commercial_inquiry_image.unique_text_name

    @expected.to = @rolf.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'news@mushroomobserver.org'
    @expected.reply_to = @mary.email
    @expected.content_type = "text/html"
    @expected.set_content_type "text", "html", { "charset" => CHARSET }

    # commercial_inquiry(sender, image, commercial_inquiry)
    account_mailer = AccountMailer.create_commercial_inquiry(@mary, @commercial_inquiry_image,
      'Did test_commercial_inquiry work?')
    assert_equal @expected.encoded, account_mailer.encoded
  end

  def test_denied
    @expected.body = read_fixture('denied')
    @expected.subject = '[MO] User Creation Blocked'
    @expected.to = 'nathan@collectivesource.com'
    @expected.from = 'accounts@mushroomobserver.org'
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }

    # denied(user)
    assert_equal @expected.encoded, AccountMailer.create_denied(@junk).encoded
  end

  def test_email_features
    @expected.body    = read_fixture('email_features')
    @expected.subject = 'New Mushroom Observer Features'

    @expected.to = @rolf.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'news@mushroomobserver.org'
    @expected.set_content_type "text", "html", { "charset" => CHARSET }

    # email_features(user, features)
    assert_equal @expected.encoded, AccountMailer.create_email_features(@rolf, 'A feature').encoded
  end

  def test_new_password
    @expected.body = read_fixture('new_password')
    @expected.subject = 'New Password for Mushroom Observer Account'
    @expected.to = @rolf.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'accounts@mushroomobserver.org'
    @expected.set_content_type "text", "html", { "charset" => CHARSET }

    # new_password(user, password)
    assert_equal @expected.encoded, AccountMailer.create_new_password(@rolf, 'A password').encoded
  end

  def test_user_question
    @expected.body = read_fixture('user_question')
    subject = 'Interesting idea'
    @expected.subject = subject
    @expected.to = @detailed_unknown.user.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'news@mushroomobserver.org'
    @expected.reply_to = @rolf.email
    @expected.set_content_type "text", "html", { "charset" => CHARSET }

    # user_question(sender, user, subject, content)
    assert_equal @expected.encoded, AccountMailer.create_user_question(@rolf, @mary, subject, 'Shall we discuss it in email?').encoded
  end

  def test_observation_question
    @expected.body = read_fixture('observation_question')
    @expected.subject = 'Question about ' + @detailed_unknown.unique_text_name
    @expected.to = @detailed_unknown.user.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'news@mushroomobserver.org'
    @expected.reply_to = @rolf.email
    @expected.set_content_type "text", "html", { "charset" => CHARSET }

    # observation_question(sender, observation, question)
    assert_equal @expected.encoded, AccountMailer.create_observation_question(@rolf, @detailed_unknown, 'Where did you find it?').encoded
  end

  def test_verify
    @expected.body = read_fixture('verify')
    @expected.subject = 'Email Verification for Mushroom Observer'
    @expected.to = @mary.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'accounts@mushroomobserver.org'
    @expected.set_content_type "text", "html", { "charset" => CHARSET }

    # verify(user)
    assert_equal @expected.encoded, AccountMailer.create_verify(@mary).encoded
  end

  def test_webmaster_question
    sender = @mary.email # Technically you don't need a user, just an email address
    @expected.body = read_fixture('webmaster_question')
    @expected.subject = '[MO] Question from ' + sender
    @expected.to = 'webmaster@mushroomobserver.org'
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = sender
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }

    # verify(user)
    assert_equal @expected.encoded, AccountMailer.create_webmaster_question(sender, 'A question').encoded
  end

  def test_naming_for_observer
    @expected.body = read_fixture('naming_for_observer')
    @expected.subject = 'Mushroom Observer Research Request'
    @expected.to = @rolf.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'news@mushroomobserver.org'
    @expected.set_content_type "text", "html", { "charset" => CHARSET }

    assert_equal @expected.encoded, AccountMailer.create_naming_for_observer(@rolf, @agaricus_campestris_naming, @agaricus_campestris_notification_with_note).encoded
  end

  def test_naming_for_tracker
    @expected.body = read_fixture('naming_for_tracker')
    @expected.subject = 'Mushroom Observer Naming Notification'
    @expected.to = @mary.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'news@mushroomobserver.org'
    @expected.set_content_type "text", "html", { "charset" => CHARSET }

    assert_equal @expected.encoded, AccountMailer.create_naming_for_tracker(@mary, @agaricus_campestris_naming).encoded
  end

  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/account_mailer/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end
end
