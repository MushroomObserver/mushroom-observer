require File.dirname(__FILE__) + '/../test_helper'
require 'account_mailer'

class AccountMailerTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/account_mailer'

  fixtures :comments
  fixtures :images
  fixtures :images_observations
  fixtures :licenses
  fixtures :locations
  fixtures :names
  fixtures :naming_reasons
  fixtures :namings
  fixtures :notifications
  fixtures :observations
  fixtures :past_locations
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

  # At the moment at least Redcloth produces slightly different output on Nathan's
  # laptop than on Jason's.  I've gotten it down to just these <br>'s.  It's easiest
  # to convert everything to Nathan's format.  (Arg, and some extraneous blank
  # lines and leading whitespace -- I'll remove them all from both, so there.)
  def fix_mac_vs_pc!(email)
    email.gsub!(/<br \/>\n/, '<br/>')
    email.gsub!(/&#38;/, '&amp;')
    email.gsub!(/ &#8212;/, '&#8212;')
    email.gsub!(/^ +/, '')
    email.gsub!(/[\n\r]+/, "\n")
  end

  def test_email_1
    email = AccountMailer.create_admin_request(@katrina, @rolf,
      @eol_project, 'Please do something or other', 'and this is why...').encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/admin_request.html", "#{FIXTURES_PATH}/admin_request.html.mac")
    @rolf.email_html = false
    email = AccountMailer.create_admin_request(@katrina, @rolf,
      @eol_project, 'Please do something or other', 'and this is why...').encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/admin_request.text")
  end

  def test_email_2
    email = AccountMailer.create_author_request(@katrina, @rolf,
      @coprinus_comatus, 'Please do something or other', 'and this is why...').encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/author_request.html", "#{FIXTURES_PATH}/author_request.html.mac")
    @rolf.email_html = false
    email = AccountMailer.create_author_request(@katrina, @rolf,
      @coprinus_comatus, 'Please do something or other', 'and this is why...').encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/author_request.text")
  end

  def test_email_3
    email = AccountMailer.create_comment(@dick, @rolf, @minimal_unknown, @another_comment).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/comment_response.html", "#{FIXTURES_PATH}/comment_response.html.mac")
    @rolf.email_html = false
    email = AccountMailer.create_comment(@dick, @rolf, @minimal_unknown, @another_comment).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/comment_response.text")
  end

  def test_email_4
    email = AccountMailer.create_comment(@rolf, @mary,
      @minimal_unknown, @minimal_comment).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/comment.html", "#{FIXTURES_PATH}/comment.html.mac")
    @mary.email_html = false
    email = AccountMailer.create_comment(@rolf, @mary,
      @minimal_unknown, @minimal_comment).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/comment.text")
  end

  def test_email_5
    email = AccountMailer.create_commercial_inquiry(@mary, @commercial_inquiry_image,
      'Did test_commercial_inquiry work?').encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/commercial_inquiry.html", "#{FIXTURES_PATH}/commercial_inquiry.html.mac")
    @commercial_inquiry_image.user.email_html = false
    email = AccountMailer.create_commercial_inquiry(@mary, @commercial_inquiry_image,
      'Did test_commercial_inquiry work?').encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/commercial_inquiry.text")
  end

  def test_email_6
    # The umlaut in Mull. is making it do weird encoding on the subject line.
    @coprinus_comatus.search_name = @coprinus_comatus.search_name.to_ascii
    email = AccountMailer.create_consensus_change(@dick, @mary, @coprinus_comatus_obs, @agaricus_campestris, @coprinus_comatus, @coprinus_comatus_obs.created).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/consensus_change.html", "#{FIXTURES_PATH}/consensus_change.html.mac")
    @mary.email_html = false
    email = AccountMailer.create_consensus_change(@dick, @mary, @coprinus_comatus_obs, @agaricus_campestris, @coprinus_comatus, @coprinus_comatus_obs.created).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/consensus_change.text")
  end

  def test_email_7
    email = AccountMailer.create_denied(@junk).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/denied.text")
  end

  def test_email_8
    email = AccountMailer.create_email_features(@rolf, 'A feature').encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/email_features.html", "#{FIXTURES_PATH}/email_features.html.mac")
    @rolf.email_html = false
    email = AccountMailer.create_email_features(@rolf, 'A feature').encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/email_features.text")
  end

  def test_email_9
    email = AccountMailer.create_name_change(@dick, @mary, @peltigera.modified, @peltigera, 1, 2, @peltigera.review_status).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/name_change.html", "#{FIXTURES_PATH}/name_change.html.mac")
    @mary.email_html = false
    email = AccountMailer.create_name_change(@dick, @mary, @peltigera.modified, @peltigera, 1, 2, @peltigera.review_status).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/name_change.text.pc",
                                    "#{FIXTURES_PATH}/name_change.text.mac")
  end

  def test_email_9b
    # Test for bug that occurred in the wild
    email = AccountMailer.create_name_change(@dick, @mary, @peltigera.modified, @peltigera, 0, 1, @peltigera.review_status).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/name_change2.html")
  end

  def test_email_10
    email = AccountMailer.create_name_proposal(@mary, @rolf, @coprinus_comatus_other_naming, @coprinus_comatus_obs).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/name_proposal.html", "#{FIXTURES_PATH}/name_proposal.html.mac")
    @rolf.email_html = false
    email = AccountMailer.create_name_proposal(@mary, @rolf, @coprinus_comatus_other_naming, @coprinus_comatus_obs).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/name_proposal.text")
  end

  def test_email_11
    email = AccountMailer.create_naming_for_observer(@rolf, @agaricus_campestris_naming,
      @agaricus_campestris_notification_with_note).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/naming_for_observer.html", "#{FIXTURES_PATH}/naming_for_observer.html.mac")
    @rolf.email_html = false
    email = AccountMailer.create_naming_for_observer(@rolf, @agaricus_campestris_naming,
      @agaricus_campestris_notification_with_note).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/naming_for_observer.text")
  end

  def test_email_12
    email = AccountMailer.create_naming_for_tracker(@mary, @agaricus_campestris_naming).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/naming_for_tracker.html", "#{FIXTURES_PATH}/naming_for_tracker.html.mac")
    @mary.email_html = false
    email = AccountMailer.create_naming_for_tracker(@mary, @agaricus_campestris_naming).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/naming_for_tracker.text")
  end

  def test_email_13
    email = AccountMailer.create_new_password(@rolf, 'A password').encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/new_password.html", "#{FIXTURES_PATH}/new_password.html.mac")
    @rolf.email_html = false
    email = AccountMailer.create_new_password(@rolf, 'A password').encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/new_password.text")
  end

  def test_email_14
    # The umlaut in Mull. is making it do weird encoding on the subject line.
    @coprinus_comatus_obs.name.search_name = @coprinus_comatus.search_name.to_ascii
    @coprinus_comatus_obs.name.display_name = @coprinus_comatus.display_name.to_ascii
    email = AccountMailer.create_observation_change(@dick, @mary, @coprinus_comatus_obs,
      'date,location,specimen,is_collection_location,notes,thumb_image_id,added_image,removed_image',
      @coprinus_comatus_obs.created).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/observation_change.html", "#{FIXTURES_PATH}/observation_change.html.mac")
    email = AccountMailer.create_observation_change(@dick, @mary, nil,
      '**__Coprinus comatus__** L. (123)', @coprinus_comatus_obs.created).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/observation_destroy.html")
    @mary.email_html = false
    email = AccountMailer.create_observation_change(@dick, @mary, @coprinus_comatus_obs,
      'date,location,specimen,is_collection_location,notes,thumb_image_id,added_image,removed_image',
      @coprinus_comatus_obs.created).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/observation_change.text")
    email = AccountMailer.create_observation_change(@dick, @mary, nil,
      '**__Coprinus comatus__** L. (123)', @coprinus_comatus_obs.created).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/observation_destroy.text")
  end

  def test_email_15
    email = AccountMailer.create_observation_question(@rolf, @detailed_unknown,
      'Where did you find it?').encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/observation_question.html", "#{FIXTURES_PATH}/observation_question.html.mac")
    @detailed_unknown.user.email_html = false
    email = AccountMailer.create_observation_question(@rolf, @detailed_unknown,
      'Where did you find it?').encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/observation_question.text")
  end

  def test_email_16
    email = AccountMailer.create_publish_name(@mary, @rolf, @agaricus_campestris).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/publish_name.html", "#{FIXTURES_PATH}/publish_name.html.mac")
    @rolf.email_html = false
    email = AccountMailer.create_publish_name(@mary, @rolf, @agaricus_campestris).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/publish_name.text")
  end

  def test_email_17
    email = AccountMailer.create_user_question(@rolf, @mary, 'Interesting idea',
      'Shall we discuss it in email?').encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/user_question.html", "#{FIXTURES_PATH}/user_question.html.mac")
    @mary.email_html = false
    email = AccountMailer.create_user_question(@rolf, @mary, 'Interesting idea',
      'Shall we discuss it in email?').encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/user_question.text")
  end

  def test_email_18
    email = AccountMailer.create_verify(@mary).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/verify.html", "#{FIXTURES_PATH}/verify.html.mac")
    @mary.email_html = false
    email = AccountMailer.create_verify(@mary).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/verify.text")
  end

  def test_email_19
    email = AccountMailer.create_webmaster_question(@mary.email, 'A question').encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/webmaster_question.text")
  end

  def test_email_20
    email = AccountMailer.create_location_change(@dick, @mary, @albion.modified, @albion, 0, 1).encoded
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, "#{FIXTURES_PATH}/location_change.html", "#{FIXTURES_PATH}/location_change.html.mac")
    @mary.email_html = false
    email = AccountMailer.create_location_change(@dick, @mary, @albion.modified, @albion, 0, 1).encoded
    assert_string_equal_file(email, "#{FIXTURES_PATH}/location_change.text")
  end
end
