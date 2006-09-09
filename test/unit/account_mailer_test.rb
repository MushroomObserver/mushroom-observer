require File.dirname(__FILE__) + '/../test_helper'
require 'account_mailer'

class AccountMailerTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"

  include ActionMailer::Quoting

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }
  end

  def test_commercial_inquiry
    @expected.subject = 'AccountMailer#commercial_inquiry'
    @expected.body    = read_fixture('commercial_inquiry')
    @expected.date    = Time.now

    # commercial_inquiry(sender, image, commercial_inquiry)
    assert_equal @expected.encoded, AccountMailer.create_commercial_inquiry(@expected.date).encoded
  end

  def test_email_features
    @expected.subject = 'AccountMailer#email_features'
    @expected.body    = read_fixture('email_features')
    @expected.date    = Time.now

    # email_features(user, features)
    assert_equal @expected.encoded, AccountMailer.create_email_features(@expected.date).encoded
  end

  def test_new_password
    @expected.subject = 'AccountMailer#new_password'
    @expected.body    = read_fixture('new_password')
    @expected.date    = Time.now

    # new_password(user, password)
    assert_equal @expected.encoded, AccountMailer.create_new_password(@expected.date).encoded
  end

  def test_question
    @expected.subject = 'AccountMailer#question'
    @expected.body    = read_fixture('question')
    @expected.date    = Time.now

    # question(sender, observation, question)
    assert_equal @expected.encoded, AccountMailer.create_question(@expected.date).encoded
  end

  def test_verify
    @expected.subject = 'AccountMailer#verify'
    @expected.body    = read_fixture('verify')
    @expected.date    = Time.now

    # verify(user)
    assert_equal @expected.encoded, AccountMailer.create_verify(@expected.date).encoded
  end

  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/account_mailer/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end
end
