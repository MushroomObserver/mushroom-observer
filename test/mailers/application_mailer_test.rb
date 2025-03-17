# frozen_string_literal: true

require("test_helper")
require("application_mailer")

class ApplicationMailerTest < UnitTestCase
  FIXTURES_PATH = "#{File.dirname(__FILE__)}/../application_mailer".freeze

  def setup
    # Disable cop; there's no block in which to limit the time zone change
    I18n.locale = :en # rubocop:disable Rails/I18nLocaleAssignment
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
      email = String.new(whole_email(space: true))
      assert_string_equal_file(email, *text_files)
    end

    return unless html_files.any?

    user.email_html = true if user
    yield
    email = String.new(whole_email(space: false))
    assert_string_equal_file(email, *html_files)
  end

  # Tests used to be brittle because they compared the entire encoded email,
  # including the exact line breaks enforced by the gem (after version 2.7.1).
  # It was impossible to anticipate line breaks in dynamically inserted text.
  # Here instead we are using `mail` gem's `decoded` method to get the email
  # body, adding email fields back into it, for string comparison.
  # - Nimmo 06/2022

  # NOTE: `{html_mail}.decoded` reproduces html indents faithfully!
  # Indents need to be removed from the .erb email build templates, or else
  # reproduced in the mail test fixtures exactly.

  # Build a whole email string, minus extra headers and force-encoded newlines.
  def whole_email(space: false)
    last = ActionMailer::Base.deliveries.last
    # Text emails expect a newline before the body, html does not
    newline = space ? "\n" : ""
    <<~"EMAIL"
      From: #{last.from.first}
      Reply-To: #{last.reply_to.first}
      To: #{last.to.first}
      Subject: #{last.subject}
      #{newline + last.decoded}
    EMAIL
  end

  ##############################################################################

  def test_add_herbarium_record_email
    herbarium_record = herbarium_records(:interesting_unknown)
    run_mail_test("add_herbarium_record_not_curator", rolf) do
      AddHerbariumRecordMailer.build(mary, rolf, herbarium_record).deliver_now
    end
  end

  def test_admin_email
    project = projects(:eol_project)
    run_mail_test("admin_request", rolf) do
      ProjectAdminRequestMailer.build(
        katrina, rolf, project,
        "Please do something or other", "and this is why..."
      ).deliver_now
    end
  end

  def test_approval_email
    run_mail_test("approval", rolf) do
      ApprovalMailer.build(katrina, "test subject", "test content").
        deliver_now
    end
  end

  def test_author_email
    obj = names(:coprinus_comatus)
    run_mail_test("author_request", rolf) do
      AuthorMailer.build(katrina, rolf, obj.description,
                         "Please do something or other", "and this is why...").
        deliver_now
    end
  end

  def test_comment_email
    obs = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_2)
    run_mail_test("comment_response", rolf) do
      CommentMailer.build(dick, rolf, obs, comment).deliver_now
    end
  end

  def test_comment_email2
    obs = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_1)
    run_mail_test("comment", mary) do
      CommentMailer.build(rolf, mary, obs, comment).deliver_now
    end
  end

  def test_commercial_email
    image = images(:commercial_inquiry_image)
    run_mail_test("commercial_inquiry", image.user) do
      CommercialInquiryMailer.build(
        mary, image, "Did test_commercial_inquiry work?"
      ).deliver_now
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
      ConsensusChangeMailer.build(email).deliver_now
    end
  end

  def test_features_email
    run_mail_test("email_features", rolf) do
      FeaturesMailer.build(rolf, "A feature").deliver_now
    end
  end

  def test_location_change_email
    loc = locations(:albion)
    desc = loc.description
    run_mail_test("location_change", mary) do
      LocationChangeMailer.build(dick, mary, loc.updated_at,
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
      NameChangeMailer.build(email).deliver_now
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
      NameChangeMailer.build(email).deliver_now
    end
  end

  def test_name_proposal_email
    naming = namings(:coprinus_comatus_other_naming)
    obs = observations(:coprinus_comatus_obs)
    run_mail_test("name_proposal", rolf) do
      NameProposalMailer.build(mary, rolf, naming, obs).deliver_now
    end
  end

  def test_naming_observer_email
    naming = namings(:agaricus_campestris_naming)
    notification = name_trackers(:agaricus_campestris_name_tracker_with_note)
    run_mail_test("naming_for_observer", rolf) do
      NamingObserverMailer.build(rolf, naming, notification).deliver_now
    end
  end

  def test_naming_tracker_email
    naming = namings(:agaricus_campestris_naming)
    run_mail_test("naming_for_tracker", mary) do
      NamingTrackerMailer.build(mary, naming).deliver_now
    end
  end

  def test_password_email
    run_mail_test("new_password", rolf) do
      PasswordMailer.build(rolf, "A password").deliver_now
    end
  end

  def test_observation_change_email
    obs = observations(:coprinus_comatus_obs)
    name = obs.name

    # The umlaut in Mull. is making it do weird encoding on the subject line.
    name.search_name = name.search_name.to_ascii
    name.display_name = name.display_name.to_ascii

    run_mail_test("observation_change", mary) do
      ObservationChangeMailer.build(
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
      ObservationChangeMailer.build(
        dick, mary, nil, "**__Coprinus comatus__** L. (123)", obs.created_at
      ).deliver_now
    end
  end

  def test_observer_question_email
    obs = observations(:detailed_unknown_obs)
    run_mail_test("observation_question", obs.user) do
      ObserverQuestionMailer.build(rolf, obs, "Where did you find it?").
        deliver_now
    end
  end

  def test_publish_name_question
    name = names(:agaricus_campestris)
    run_mail_test("publish_name", rolf) do
      PublishNameMailer.build(mary, rolf, name).deliver_now
    end
  end

  def test_user_email
    run_mail_test("user_question", mary) do
      UserQuestionMailer.build(
        rolf, mary, "Interesting idea", "Shall we discuss it in email?"
      ).deliver_now
    end
  end

  def test_verify_email
    run_mail_test("verify", mary) do
      VerifyAccountMailer.build(mary).deliver_now
    end
  end

  def test_webmaster_email
    run_mail_test("webmaster_question") do
      WebmasterMailer.build(
        sender_email: mary.email,
        content: "A question"
      ).deliver_now
    end
  end

  def test_verify_api_key_email
    run_mail_test("verify_api_key", rolf) do
      VerifyAPIKeyMailer.build(rolf, dick, api_keys(:rolfs_api_key)).deliver_now
    end
  end

  def test_valid_email_address
    assert_true(ApplicationMailer.valid_email_address?("joe@schmo.com"))
    assert_false(ApplicationMailer.valid_email_address?("joe.schmo.com"))
    assert_false(ApplicationMailer.valid_email_address?(""))
  end

  def test_undeliverable_email
    mary.update(email: "bogus.address")
    UserQuestionMailer.build(rolf, mary, "subject", "body").deliver_now
    assert_nil(ActionMailer::Base.deliveries.last,
               "Should not have delivered an email to 'bogus.address'.")
  end

  def test_opt_out
    mary.update(no_emails: true)
    UserQuestionMailer.build(rolf, mary, "subject", "body").deliver_now
    assert_nil(ActionMailer::Base.deliveries.last,
               "Should not deliver email if recipient has opted out.")
  end
end
