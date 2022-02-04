# frozen_string_literal: true

require("test_helper")
require("account_mailer")

class AccountMailerTest < UnitTestCase
  FIXTURES_PATH = File.dirname(__FILE__) + "/../account_mailer"

  def setup
    I18n.locale = "en"
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    @expected = Mail.new
    @expected.mime_version = "1.0"
    super
  end

  # Run off an email in both HTML and text form.
  def run_mail_test(name, user = nil)
    text_files = Dir.glob("#{FIXTURES_PATH}/#{name}.text*").
                 reject { |x| x.end_with?(".new") }
    html_files = Dir.glob("#{FIXTURES_PATH}/#{name}.html*").
                 reject { |x| x.end_with?(".new") }

    assert(text_files.any? || html_files.any?)

    if text_files.any?
      user.email_html = false if user
      yield
      email = ActionMailer::Base.deliveries.last.encoded
      email = remove_extraneous_email_headers(email)
      assert_string_equal_file(email, *text_files)
    end

    return unless html_files.any?

    user.email_html = true if user
    yield
    email = ActionMailer::Base.deliveries.last.encoded
    email = remove_extraneous_email_headers(email)
    fix_mac_vs_pc!(email)
    assert_string_equal_file(email, *html_files)
    end

  # At the moment at least Redcloth produces slightly different output on
  # Nathan's laptop than on Jason's.  I'm trying to reduce both responses to a
  # common form so that we don't need to continue to tweak two separate copies
  # of every email response.  But I'm failing...
  def fix_mac_vs_pc!(email)
    email.gsub!(/&#38;/, "&amp;")
    email.gsub!(/ &#8212;/, "&#8212;")
    email.gsub!(/^\s+/, "")
    email.gsub!(/\r\n?/, "\n")
  end

  def remove_extraneous_email_headers(str)
    in_header = true
    keep_wrapped_line = false
    str.split("\n").select do |line|
      in_header = false if /^\s*$|<html>/.match?(line)
      if !in_header
        true
      elsif /^(To|From|Reply-To|Cc|Bcc|Subject):/.match?(line)
        keep_wrapped_line = true
      elsif keep_wrapped_line && line !~ /^[A-Z][\w\-]+:/
        true
      else
        keep_wrapped_line = false
      end
    end.join("\n")
  end

  ##############################################################################

  def test_add_herbarium_record_email
    herbarium_record = herbarium_records(:interesting_unknown)
    run_mail_test("add_herbarium_record_not_curator", rolf) do
      AddHerbariumRecordEmail.build(mary, rolf, herbarium_record).deliver_now
    end
  end

  def test_admin_email
    project = projects(:eol_project)
    run_mail_test("admin_request", rolf) do
      AdminEmail.build(katrina, rolf, project,
                       "Please do something or other", "and this is why...").
        deliver_now
    end
  end

  def test_author_email
    obj = names(:coprinus_comatus)
    run_mail_test("author_request", rolf) do
      AuthorEmail.build(katrina, rolf, obj.description,
                        "Please do something or other", "and this is why...").
        deliver_now
    end
  end

  def test_comment_email
    obs = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_2)
    run_mail_test("comment_response", rolf) do
      CommentEmail.build(dick, rolf, obs, comment).deliver_now
    end
  end

  def test_comment_email2
    obs = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_1)
    run_mail_test("comment", mary) do
      CommentEmail.build(rolf, mary, obs, comment).deliver_now
    end
  end

  def test_commercial_email
    image = images(:commercial_inquiry_image)
    run_mail_test("commercial_inquiry", image.user) do
      CommercialEmail.build(mary, image,
                            "Did test_commercial_inquiry work?").deliver_now
    end
  end

  def test_consensus_change_email
    obs = observations(:coprinus_comatus_obs)
    name1 = names(:agaricus_campestris)
    name2 = obs.name

    # The umlaut in Mull. is making it do weird encoding on the subject line.
    name2.search_name = name2.search_name.to_ascii
    name2.display_name = name2.display_name.to_ascii

    run_mail_test("consensus_change", mary) do
      email = QueuedEmail::ConsensusChange.create_email(dick, mary, obs,
                                                        name1, name2)
      ConsensusChangeEmail.build(email).deliver_now
    end
  end

  def test_denied_email
    run_mail_test("denied") do
      DeniedEmail.build(junk).deliver_now
    end
  end

  def test_features_email
    run_mail_test("email_features", rolf) do
      FeaturesEmail.build(rolf, "A feature").deliver_now
    end
  end

  def test_location_change_email
    loc = locations(:albion)
    desc = loc.description
    run_mail_test("location_change", mary) do
      LocationChangeEmail.build(dick, mary, loc.updated_at,
                                ObjectChange.new(loc, 1, 2),
                                ObjectChange.new(desc, 1, 2)).deliver_now
    end
  end

  def test_name_change_email
    name = names(:peltigera)
    desc = name.description
    run_mail_test("name_change", mary) do
      email = QueuedEmail::NameChange.create_email(dick, mary,
                                                   name, desc, true, true)
      NameChangeEmail.build(email).deliver_now
    end
  end

  def test_name_change_email2
    # Test for bug that occurred in the wild
    name = names(:peltigera)
    desc = name.description
    run_mail_test("name_change2", mary) do
      name.version = 1
      desc.version = 1
      email = QueuedEmail::NameChange.create_email(dick, mary,
                                                   name, desc, false, true)
      assert(email.old_name_version.zero?)
      assert(email.old_description_version.zero?)
      NameChangeEmail.build(email).deliver_now
    end
  end

  def test_name_proposal_email
    naming = namings(:coprinus_comatus_other_naming)
    obs = observations(:coprinus_comatus_obs)
    run_mail_test("name_proposal", rolf) do
      NameProposalEmail.build(mary, rolf, naming, obs).deliver_now
    end
  end

  def test_naming_observer_email
    naming = namings(:agaricus_campestris_naming)
    notification = notifications(:agaricus_campestris_notification_with_note)
    run_mail_test("naming_for_observer", rolf) do
      NamingObserverEmail.build(rolf, naming, notification).deliver_now
    end
  end

  def test_naming_tracker_email
    naming = namings(:agaricus_campestris_naming)
    run_mail_test("naming_for_tracker", mary) do
      NamingTrackerEmail.build(mary, naming).deliver_now
    end
  end

  def test_password_email
    run_mail_test("new_password", rolf) do
      PasswordEmail.build(rolf, "A password").deliver_now
    end
  end

  def test_observation_change_email
    obs = observations(:coprinus_comatus_obs)
    name = obs.name

    # The umlaut in Mull. is making it do weird encoding on the subject line.
    name.search_name = name.search_name.to_ascii
    name.display_name = name.display_name.to_ascii

    run_mail_test("observation_change", mary) do
      ObservationChangeEmail.build(
        dick, mary, obs,
        "date,location,specimen,is_collection_location,notes," \
        "thumb_image_id,added_image,removed_image",
        obs.created_at
      ).deliver_now
    end
  end

  def test_observation_destroy_email
    obs = observations(:coprinus_comatus_obs)
    name = obs.name

    # The umlaut in Mull. is making it do weird encoding on the subject line.
    name.search_name = name.search_name.to_ascii
    name.display_name = name.display_name.to_ascii

    run_mail_test("observation_destroy", mary) do
      ObservationChangeEmail.build(
        dick, mary, nil, "**__Coprinus comatus__** L. (123)", obs.created_at
      ).deliver_now
    end
  end

  def test_observation_email
    obs = observations(:detailed_unknown_obs)
    run_mail_test("observation_question", obs.user) do
      ObservationEmail.build(rolf, obs, "Where did you find it?").
        deliver_now
    end
  end

  def test_publish_name_question
    name = names(:agaricus_campestris)
    run_mail_test("publish_name", rolf) do
      PublishNameEmail.build(mary, rolf, name).deliver_now
    end
  end

  def test_user_email
    run_mail_test("user_question", mary) do
      UserEmail.build(
        rolf, mary, "Interesting idea", "Shall we discuss it in email?"
      ).deliver_now
    end
  end

  def test_verify_email
    run_mail_test("verify", mary) do
      VerifyEmail.build(mary).deliver_now
    end
  end

  def test_webmaster_email
    run_mail_test("webmaster_question") do
      WebmasterEmail.build(mary.email, "A question").deliver_now
    end
  end

  def test_verify_api_key_email
    run_mail_test("verify_api_key", rolf) do
      VerifyAPIKeyEmail.build(rolf, dick, api_keys(:rolfs_api_key)).deliver_now
    end
  end
end
