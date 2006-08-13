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

  def test_new_account
    @expected.subject = 'AccountMailer#new_account'
    @expected.body    = read_fixture('new_account')
    @expected.date    = Time.now

    assert_equal @expected.encoded, AccountMailer.create_new_account(@expected.date).encoded
  end

  def test_new_password
    @expected.subject = 'AccountMailer#new_password'
    @expected.body    = read_fixture('new_password')
    @expected.date    = Time.now

    assert_equal @expected.encoded, AccountMailer.create_new_password(@expected.date).encoded
  end

  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/account_mailer/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end
end
