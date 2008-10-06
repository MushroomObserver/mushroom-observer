require File.dirname(__FILE__) + '/../test_helper'
require 'account_mailer'

class AccountMailerTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/account_mailer'

  fixtures :users
  fixtures :images
  fixtures :observations
  fixtures :images_observations
  fixtures :names
  fixtures :namings
  fixtures :comments
  fixtures :notifications
  fixtures :projects
  fixtures :user_groups
  fixtures :user_groups_users

  def setup
    Locale.code = "en-US"
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    @expected = TMail::Mail.new
    @expected.mime_version = '1.0'
  end

  def test_emails
    assert_string_equal_file("#{FIXTURES_PATH}/comment_inquiry",
      AccountMailer.create_comment(@mary, @detailed_unknown.user,
        @detailed_unknown, @minimal_comment).encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/commercial_inquiry",
      AccountMailer.create_commercial_inquiry(@mary, @commercial_inquiry_image,
        'Did test_commercial_inquiry work?').encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/denied",
      AccountMailer.create_denied(@junk).encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/email_features",
      AccountMailer.create_email_features(@rolf, 'A feature').encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/new_password",
      AccountMailer.create_new_password(@rolf, 'A password').encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/user_question",
      AccountMailer.create_user_question(@rolf, @mary, 'Interesting idea',
        'Shall we discuss it in email?').encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/admin_request",
      AccountMailer.create_admin_request(@katrina, @eol_project,
        'Please do something or other', 'and this is why...').encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/observation_question",
      AccountMailer.create_observation_question(@rolf, @detailed_unknown,
        'Where did you find it?').encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/verify",
      AccountMailer.create_verify(@mary).encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/webmaster_question",
      AccountMailer.create_webmaster_question(@mary.email, 'A question').encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/naming_for_observer",
      AccountMailer.create_naming_for_observer(@rolf, @agaricus_campestris_naming,
        @agaricus_campestris_notification_with_note).encoded)

    assert_string_equal_file("#{FIXTURES_PATH}/naming_for_tracker",
      AccountMailer.create_naming_for_tracker(@mary, @agaricus_campestris_naming).encoded)
  end
end
