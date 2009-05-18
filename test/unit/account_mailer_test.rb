require File.dirname(__FILE__) + '/../test_helper'
require 'account_mailer'

class AccountMailerTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/account_mailer'

  fixtures :comments
  fixtures :images
  fixtures :images_observations
  fixtures :licenses
  fixtures :names
  fixtures :naming_reasons
  fixtures :namings
  fixtures :notifications
  fixtures :observations
  fixtures :past_names
  fixtures :projects
  fixtures :user_groups
  fixtures :user_groups_users
  fixtures :users

  def setup
    Locale.code = "en-US"
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    @expected = TMail::Mail.new
    @expected.mime_version = '1.0'
  end

  def test_email_1
    assert_string_equal_file("#{FIXTURES_PATH}/admin_request.text",
      AccountMailer.create_admin_request(@katrina, @eol_project,
        'Please do something or other', 'and this is why...').encoded)
  end

  def test_email_2
    assert_string_equal_file("#{FIXTURES_PATH}/author_request.text",
      AccountMailer.create_author_request(@katrina, @coprinus_comatus,
        'Please do something or other', 'and this is why...').encoded)
  end

  def test_email_3
    assert_string_equal_file("#{FIXTURES_PATH}/comment_response.html",
      AccountMailer.create_comment(@dick, @rolf, @minimal_unknown, @another_comment).encoded)
    @rolf.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/comment_response.text",
      AccountMailer.create_comment(@dick, @rolf, @minimal_unknown, @another_comment).encoded)
  end

  def test_email_4
    assert_string_equal_file("#{FIXTURES_PATH}/comment.html",
      AccountMailer.create_comment(@rolf, @mary,
        @minimal_unknown, @minimal_comment).encoded)
    @mary.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/comment.text",
      AccountMailer.create_comment(@rolf, @mary,
        @minimal_unknown, @minimal_comment).encoded)
  end

  def test_email_5
    assert_string_equal_file("#{FIXTURES_PATH}/commercial_inquiry.html",
      AccountMailer.create_commercial_inquiry(@mary, @commercial_inquiry_image,
        'Did test_commercial_inquiry work?').encoded)
    @commercial_inquiry_image.user.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/commercial_inquiry.text",
      AccountMailer.create_commercial_inquiry(@mary, @commercial_inquiry_image,
        'Did test_commercial_inquiry work?').encoded)
  end

  def test_email_6
    # The umlaut in Mull. is making it do weird encoding on the subject line.
    @coprinus_comatus.search_name = @coprinus_comatus.search_name.to_ascii
    assert_string_equal_file("#{FIXTURES_PATH}/consensus_change.html",
      AccountMailer.create_consensus_change(@dick, @mary, @coprinus_comatus_obs, @agaricus_campestris, @coprinus_comatus, @coprinus_comatus_obs.created).encoded)
    @mary.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/consensus_change.text",
      AccountMailer.create_consensus_change(@dick, @mary, @coprinus_comatus_obs, @agaricus_campestris, @coprinus_comatus, @coprinus_comatus_obs.created).encoded)
  end

  def test_email_7
    assert_string_equal_file("#{FIXTURES_PATH}/denied.text",
      AccountMailer.create_denied(@junk).encoded)
  end

  def test_email_8
    assert_string_equal_file("#{FIXTURES_PATH}/email_features.html",
      AccountMailer.create_email_features(@rolf, 'A feature').encoded)
    @rolf.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/email_features.text",
      AccountMailer.create_email_features(@rolf, 'A feature').encoded)
  end

  def test_email_9
    assert_string_equal_file("#{FIXTURES_PATH}/name_change.html",
      AccountMailer.create_name_change(@dick, @mary, @peltigera.modified, @peltigera, 1, 2, @peltigera.review_status).encoded)
    @mary.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/name_change.text",
      AccountMailer.create_name_change(@dick, @mary, @peltigera.modified, @peltigera, 1, 2, @peltigera.review_status).encoded)
  end

  def test_email_10
    assert_string_equal_file("#{FIXTURES_PATH}/name_proposal.html",
      AccountMailer.create_name_proposal(@mary, @rolf, @coprinus_comatus_other_naming, @coprinus_comatus_obs).encoded)
    @rolf.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/name_proposal.text",
      AccountMailer.create_name_proposal(@mary, @rolf, @coprinus_comatus_other_naming, @coprinus_comatus_obs).encoded)
  end

  def test_email_11
    assert_string_equal_file("#{FIXTURES_PATH}/naming_for_observer.text",
      AccountMailer.create_naming_for_observer(@rolf, @agaricus_campestris_naming,
        @agaricus_campestris_notification_with_note).encoded)
  end

  def test_email_12
    assert_string_equal_file("#{FIXTURES_PATH}/naming_for_tracker.html",
      AccountMailer.create_naming_for_tracker(@mary, @agaricus_campestris_naming).encoded)
    @mary.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/naming_for_tracker.text",
      AccountMailer.create_naming_for_tracker(@mary, @agaricus_campestris_naming).encoded)
  end

  def test_email_13
    assert_string_equal_file("#{FIXTURES_PATH}/new_password.html",
      AccountMailer.create_new_password(@rolf, 'A password').encoded)
    @rolf.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/new_password.text",
      AccountMailer.create_new_password(@rolf, 'A password').encoded)
  end

  def test_email_14
    # The umlaut in Mull. is making it do weird encoding on the subject line.
    @coprinus_comatus_obs.name.search_name = @coprinus_comatus.search_name.to_ascii
    @coprinus_comatus_obs.name.display_name = @coprinus_comatus.display_name.to_ascii
    assert_string_equal_file("#{FIXTURES_PATH}/observation_change.html",
      AccountMailer.create_observation_change(@dick, @mary, @coprinus_comatus_obs,
        'date,location,specimen,is_collection_location,notes,thumb_image_id,added_image,removed_image',
        @coprinus_comatus_obs.created).encoded)
    assert_string_equal_file("#{FIXTURES_PATH}/observation_destroy.html",
      AccountMailer.create_observation_change(@dick, @mary, nil,
        '**__Coprinus comatus__** L. (123)', @coprinus_comatus_obs.created).encoded)
    @mary.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/observation_change.text",
      AccountMailer.create_observation_change(@dick, @mary, @coprinus_comatus_obs,
        'date,location,specimen,is_collection_location,notes,thumb_image_id,added_image,removed_image',
        @coprinus_comatus_obs.created).encoded)
    assert_string_equal_file("#{FIXTURES_PATH}/observation_destroy.text",
      AccountMailer.create_observation_change(@dick, @mary, nil,
        '**__Coprinus comatus__** L. (123)', @coprinus_comatus_obs.created).encoded)
  end

  def test_email_15
    assert_string_equal_file("#{FIXTURES_PATH}/observation_question.html",
      AccountMailer.create_observation_question(@rolf, @detailed_unknown,
        'Where did you find it?').encoded)
    @detailed_unknown.user.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/observation_question.text",
      AccountMailer.create_observation_question(@rolf, @detailed_unknown,
        'Where did you find it?').encoded)
  end

  def test_email_16
    assert_string_equal_file("#{FIXTURES_PATH}/publish_name.html",
      AccountMailer.create_publish_name(@mary, @rolf, @agaricus_campestris).encoded)
    @rolf.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/publish_name.text",
      AccountMailer.create_publish_name(@mary, @rolf, @agaricus_campestris).encoded)
  end

  def test_email_17
    assert_string_equal_file("#{FIXTURES_PATH}/user_question.html",
      AccountMailer.create_user_question(@rolf, @mary, 'Interesting idea',
        'Shall we discuss it in email?').encoded)
    @mary.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/user_question.text",
      AccountMailer.create_user_question(@rolf, @mary, 'Interesting idea',
        'Shall we discuss it in email?').encoded)
  end

  def test_email_18
    assert_string_equal_file("#{FIXTURES_PATH}/verify.html",
      AccountMailer.create_verify(@mary).encoded)
    @mary.html_email = false
    assert_string_equal_file("#{FIXTURES_PATH}/verify.text",
      AccountMailer.create_verify(@mary).encoded)
  end

  def test_email_19
    assert_string_equal_file("#{FIXTURES_PATH}/webmaster_question.text",
      AccountMailer.create_webmaster_question(@mary.email, 'A question').encoded)
  end
end
