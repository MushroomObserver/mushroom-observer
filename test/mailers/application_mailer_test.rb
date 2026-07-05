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

  # AddHerbariumRecordMailer converted to Phlex (issue #4676) — see
  # test/mailers/zz_temp_parity_check_test.rb (reuses
  # add_herbarium_record_not_curator fixtures).

  # ProjectAdminRequestMailer converted to Phlex (issue #4676) — see
  # test/mailers/zz_temp_parity_check_test.rb (reuses admin_request
  # fixtures).

  def test_approval_email
    subject = "test subject"
    message = "test content"

    run_mail_test("approval", rolf) do
      ApprovalMailer.build(receiver: katrina, subject:, message:).deliver_now
    end
  end

  # AuthorMailer converted to Phlex (issue #4676) — see
  # test/mailers/zz_temp_parity_check_test.rb (reuses author_request
  # fixtures).

  # CommentMailer converted to Phlex (issue #4676) — its golden-file
  # byte comparison is superseded by the structural checks in
  # test/mailers/zz_temp_parity_check_test.rb, which reuses these
  # same fixtures (comment.html/.text, comment_response.html/.text).

  # CommercialInquiryMailer converted to Phlex (issue #4676) — see
  # test/mailers/zz_temp_parity_check_test.rb (reuses
  # commercial_inquiry fixtures).

  # ConsensusChangeMailer converted to Phlex (issue #4676) — see
  # test/mailers/zz_temp_parity_check_test.rb (reuses consensus_change
  # fixtures).

  def test_location_change_email
    loc = locations(:albion)
    desc = loc.description
    run_mail_test("location_change", mary) do
      LocationChangeMailer.build(
        sender: dick, receiver: mary, location: loc,
        old_loc_ver: 1, new_loc_ver: 2,
        description: desc, old_desc_ver: 1, new_desc_ver: 2
      ).deliver_now
    end
  end

  def test_name_change_email
    name = names(:peltigera)
    desc = name.description
    run_mail_test("name_change", mary) do
      NameChangeMailer.build(
        sender: dick, receiver: mary, name: name,
        old_name_ver: name.version - 1, new_name_ver: name.version,
        description: desc, old_desc_ver: desc.version - 1,
        new_desc_ver: desc.version, review_status: desc.review_status.to_s
      ).deliver_now
    end
  end

  def test_name_change_email2
    # Test for bug that occurred in the wild
    name = names(:peltigera)
    desc = name.description
    run_mail_test("name_change2", mary) do
      NameChangeMailer.build(
        sender: dick, receiver: mary, name: name,
        old_name_ver: 0, new_name_ver: 1,
        description: desc, old_desc_ver: 0, new_desc_ver: 1,
        review_status: "no_change"
      ).deliver_now
    end
  end

  # NameProposalMailer converted to Phlex (issue #4676) — see
  # test/mailers/zz_temp_parity_check_test.rb (reuses name_proposal
  # fixtures).

  # NamingObserverMailer converted to Phlex (issue #4676) — see
  # test/mailers/zz_temp_parity_check_test.rb (reuses
  # naming_for_observer fixtures).

  def test_naming_tracker_email
    naming = namings(:agaricus_campestris_naming)
    run_mail_test("naming_for_tracker", mary) do
      NamingTrackerMailer.build(receiver: mary, naming:).deliver_now
    end
  end

  # PasswordMailer converted to Phlex (issue #4676) — see
  # test/mailers/zz_temp_parity_check_test.rb (reuses new_password
  # fixtures).

  # ObservationChangeMailer converted to Phlex (issue #4676) — see
  # test/mailers/zz_temp_parity_check_test.rb (reuses
  # observation_change and observation_destroy fixtures).

  # ObserverQuestionMailer and UserQuestionMailer converted to Phlex
  # (issue #4676) — see test/mailers/zz_temp_parity_check_test.rb
  # (reuses observation_question and user_question fixtures).

  def test_verify_email
    run_mail_test("verify", mary) do
      VerifyAccountMailer.build(receiver: mary).deliver_now
    end
  end

  # WebmasterMailer converted to Phlex (issue #4676) — see
  # test/mailers/zz_temp_parity_check_test.rb (reuses
  # webmaster_question.text).

  def test_verify_api_key_email
    api_key = api_keys(:rolfs_api_key)

    run_mail_test("verify_api_key", rolf) do
      VerifyAPIKeyMailer.build(
        receiver: rolf, app_user: dick, api_key:
      ).deliver_now
    end
  end

  def test_valid_email_address
    assert_true(ApplicationMailer.valid_email_address?("joe@schmo.com"))
    assert_false(ApplicationMailer.valid_email_address?("joe.schmo.com"))
    assert_false(ApplicationMailer.valid_email_address?(""))
  end

  def test_undeliverable_email
    mary.update(email: "bogus.address")
    UserQuestionMailer.build(
      sender: rolf, receiver: mary, subject: "subject", message: "body"
    ).deliver_now
    assert_nil(ActionMailer::Base.deliveries.last,
               "Should not have delivered an email to 'bogus.address'.")
  end

  def test_opt_out
    mary.update(no_emails: true)
    UserQuestionMailer.build(
      sender: rolf, receiver: mary, subject: "subject", message: "body"
    ).deliver_now
    assert_nil(ActionMailer::Base.deliveries.last,
               "Should not deliver email if recipient has opted out.")
  end
end
