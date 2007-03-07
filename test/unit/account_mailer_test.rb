require File.dirname(__FILE__) + '/../test_helper'
require 'account_mailer'

class AccountMailerTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"
  fixtures :users
  fixtures :images
  fixtures :observations
  fixtures :names

  include ActionMailer::Quoting

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }
    @expected.mime_version = '1.0'
  end

  def test_commercial_inquiry
    @expected.body = read_fixture('commercial_inquiry')
    @expected.subject = 'Commercial Inquiry About ' + @commercial_inquiry_image.unique_text_name

    @expected.to = @rolf.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'news@mushroomobserver.org'
    @expected.reply_to = @mary.email

    # commercial_inquiry(sender, image, commercial_inquiry)
    account_mailer = AccountMailer.create_commercial_inquiry(@mary, @commercial_inquiry_image,
      'Did test_commercial_inquiry work?')
    assert_equal @expected.encoded, account_mailer.encoded
  end

  def test_denied
    @expected.body = read_fixture('denied')
    @expected.subject = 'Mushroom Observer User Creation Blocked'
    @expected.to = 'nathan@collectivesource.com'
    @expected.from = 'accounts@mushroomobserver.org'

    # denied(user)
    assert_equal @expected.encoded, AccountMailer.create_denied(@junk).encoded
  end

  def test_email_features
    @expected.body    = read_fixture('email_features')
    @expected.subject = 'New Mushroom Observer Features'

    @expected.to = @rolf.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'news@mushroomobserver.org'

    # email_features(user, features)
    assert_equal @expected.encoded, AccountMailer.create_email_features(@rolf, 'A feature').encoded
  end

  def test_new_password
    @expected.body = read_fixture('new_password')
    @expected.subject = 'New Password for Mushroom Observer Account'
    @expected.to = @rolf.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'accounts@mushroomobserver.org'

    # new_password(user, password)
    assert_equal @expected.encoded, AccountMailer.create_new_password(@rolf, 'A password').encoded
  end

  def test_question
    @expected.body = read_fixture('question')
    @expected.subject = 'Question About ' + @detailed_unknown.unique_text_name
    @expected.to = @detailed_unknown.user.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'news@mushroomobserver.org'
    @expected.reply_to = @rolf.email

    # question(sender, observation, question)
    assert_equal @expected.encoded, AccountMailer.create_question(@rolf, @detailed_unknown, 'Where did you find it?').encoded
  end

  def test_verify
    @expected.body = read_fixture('verify')
    @expected.subject = 'Mushroom Observer Email Verification'
    @expected.to = @mary.email
    @expected.bcc = 'nathan@collectivesource.com'
    @expected.from = 'accounts@mushroomobserver.org'

    # verify(user)
    assert_equal @expected.encoded, AccountMailer.create_verify(@mary).encoded
  end

  def test_webmaster_question
    sender = @mary.email # Technically you don't need a user, just an email address
    @expected.body = read_fixture('webmaster_question')
    @expected.subject    = 'Mushroom Observer Question From ' + sender
    @expected.to = 'webmaster@mushroomobserver.org'
    @expected.from = sender

    # verify(user)
    assert_equal @expected.encoded, AccountMailer.create_webmaster_question(sender, 'A question').encoded
  end

  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/account_mailer/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end
end
