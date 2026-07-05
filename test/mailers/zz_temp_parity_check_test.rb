# frozen_string_literal: true

require("test_helper")

# TEMPORARY — parity check between the golden fixtures and the Phlex
# mailer output. Not a permanent test; keep it around until every
# mailer covered by a fixture has been given its own permanent test.
class ZzTempParityCheckTest < UnitTestCase
  FIXTURES_PATH = "#{File.dirname(__FILE__)}/../application_mailer".freeze

  def setup
    I18n.locale = :en # rubocop:disable Rails/I18nLocaleAssignment
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    super
  end

  def interpolated_fixture(name)
    raw = File.read("#{FIXTURES_PATH}/#{name}")
    ERB.new(raw).result(binding)
  end

  def body_only(whole)
    whole.split("\n", 5).last
  end

  def normalize_html(html)
    frag = Nokogiri::HTML5.fragment(html)
    # Only collapse whitespace-*with-a-newline* touching a tag
    # boundary — the golden fixtures' literal template-formatting
    # newlines around some tags leave an insignificant leading/
    # trailing space in the text node that Phlex's compact output
    # never produces. A plain single space (no newline) touching a
    # tag boundary is left alone — that's meaningful inline spacing
    # (e.g. "Show this observation: " before a link), not
    # template-formatting noise.
    frag.to_html.gsub(/>[ \t]*\n[ \t]*/, ">").
      gsub(/[ \t]*\n[ \t]*</, "<").gsub(/\s+/, " ").strip
  end

  def normalize_text(text)
    text.strip.gsub(/[ \t]+\n/, "\n")
  end

  # Toggles `user.email_html`, builds the mail via the given block for
  # both styles, and force-evaluates each body immediately (mailers
  # are lazy `MessageDelivery` proxies — deferring `.body` access
  # until after both builds would let the second toggle silently
  # change the first mail's rendered content_style).
  def both_bodies(user)
    user.update!(email_html: true)
    html_body = yield.message.body.to_s
    user.update!(email_html: false)
    text_body = yield.message.body.to_s
    [html_body, text_body]
  end

  # Some fixtures use a literal "IGNORE ... IGNORE" line as a
  # placeholder for non-deterministic content (e.g. a rendered
  # timestamp) — same convention as the old assert_string_equal_file
  # harness's match_ignoring_some_bits. Substitute any actual line
  # matching an IGNORE-patterned fixture line back to that literal
  # line before comparing.
  def mask_ignored_lines(actual, template)
    return actual unless template.include?("IGNORE")

    pattern = Regexp.escape(template).gsub("IGNORE", ".*?")
    actual.sub(/\A#{pattern}\z/m, template)
  end

  def compare(label, fixture_base, mail_html, mail_text)
    fixture_html = body_only(interpolated_fixture("#{fixture_base}.html"))
    fixture_text = body_only(interpolated_fixture("#{fixture_base}.text"))

    a = normalize_html(fixture_html)
    b = mask_ignored_lines(normalize_html(mail_html), a)
    assert_equal(a, b, "#{label} HTML parity mismatch")

    ta = normalize_text(fixture_text)
    tb = mask_ignored_lines(normalize_text(mail_text), ta)
    assert_equal(ta, tb, "#{label} TEXT parity mismatch")
  end

  def test_comment_parity
    mary = users(:mary)
    rolf = users(:rolf)
    target = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_1)

    html_body, text_body = both_bodies(mary) do
      CommentMailer.build(sender: rolf, receiver: mary, target:, comment:,
                          email_type: "owner")
    end

    compare("comment", "comment", html_body, text_body)
  end

  def test_comment_response_parity
    rolf = users(:rolf)
    dick = users(:dick)
    target = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_2)

    html_body, text_body = both_bodies(rolf) do
      CommentMailer.build(sender: dick, receiver: rolf, target:, comment:,
                          email_type: "response")
    end

    compare("comment_response", "comment_response", html_body, text_body)
  end

  def test_webmaster_parity
    mail = WebmasterMailer.build(sender_email: mary.email,
                                 message: "A question").message
    fixture_text = body_only(interpolated_fixture("webmaster_question.text"))
    assert_equal(normalize_text(fixture_text), normalize_text(mail.body.to_s),
                 "webmaster_question TEXT parity mismatch")
  end

  def test_author_request_parity
    rolf = users(:rolf)
    katrina = users(:katrina)
    object = names(:coprinus_comatus).description

    html_body, text_body = both_bodies(rolf) do
      AuthorMailer.build(sender: katrina, receiver: rolf, object:,
                         subject: "Please do something or other",
                         message: "and this is why...")
    end

    compare("author_request", "author_request", html_body, text_body)
  end

  def test_observer_question_parity
    rolf = users(:rolf)
    observation = observations(:detailed_unknown_obs)

    html_body, text_body = both_bodies(observation.user) do
      ObserverQuestionMailer.build(sender: rolf, observation:,
                                   message: "Where did you find it?")
    end

    compare("observation_question", "observation_question", html_body,
            text_body)
  end

  def test_user_question_parity
    rolf = users(:rolf)
    mary = users(:mary)

    html_body, text_body = both_bodies(mary) do
      UserQuestionMailer.build(sender: rolf, receiver: mary,
                               subject: "Interesting idea",
                               message: "Shall we discuss it in email?")
    end

    compare("user_question", "user_question", html_body, text_body)
  end

  def test_commercial_inquiry_parity
    mary = users(:mary)
    image = images(:commercial_inquiry_image)

    message = "Did test_commercial_inquiry work?"
    html_body, text_body = both_bodies(image.user) do
      CommercialInquiryMailer.build(sender: mary, image:, message:)
    end

    compare("commercial_inquiry", "commercial_inquiry", html_body, text_body)
  end

  def test_admin_request_parity
    rolf = users(:rolf)
    katrina = users(:katrina)
    project = projects(:eol_project)

    html_body, text_body = both_bodies(rolf) do
      ProjectAdminRequestMailer.build(
        sender: katrina, receiver: rolf, project:,
        subject: "Please do something or other", message: "and this is why..."
      )
    end

    compare("admin_request", "admin_request", html_body, text_body)
  end

  def test_naming_observer_parity
    rolf = users(:rolf)
    naming = namings(:agaricus_campestris_naming)
    name_tracker = name_trackers(:agaricus_campestris_name_tracker_with_note)

    html_body, text_body = both_bodies(rolf) do
      NamingObserverMailer.build(receiver: rolf, naming:, name_tracker:)
    end

    compare("naming_for_observer", "naming_for_observer", html_body, text_body)
  end

  def test_password_parity
    rolf = users(:rolf)

    html_body, text_body = both_bodies(rolf) do
      PasswordMailer.build(receiver: rolf, password: "A password")
    end

    compare("new_password", "new_password", html_body, text_body)
  end

  def test_consensus_change_parity
    mary = users(:mary)
    dick = users(:dick)
    observation = observations(:coprinus_comatus_obs)
    old_name = names(:agaricus_campestris)
    new_name = observation.name

    html_body, text_body = both_bodies(mary) do
      ConsensusChangeMailer.build(sender: dick, receiver: mary, observation:,
                                  old_name:, new_name:)
    end

    compare("consensus_change", "consensus_change", html_body, text_body)
  end

  def test_name_proposal_parity
    rolf = users(:rolf)
    mary = users(:mary)
    naming = namings(:coprinus_comatus_other_naming)
    observation = observations(:coprinus_comatus_obs)

    html_body, text_body = both_bodies(rolf) do
      NameProposalMailer.build(sender: mary, receiver: rolf, naming:,
                               observation:)
    end

    compare("name_proposal", "name_proposal", html_body, text_body)
  end

  def test_observation_change_parity
    mary = users(:mary)
    dick = users(:dick)
    observation = observations(:coprinus_comatus_obs)
    note = "date,location,specimen,is_collection_location,notes," \
           "thumb_image_id,added_image,removed_image"

    html_body, text_body = both_bodies(mary) do
      ObservationChangeMailer.build(sender: dick, receiver: mary, observation:,
                                    note:, time: observation.created_at)
    end

    compare("observation_change", "observation_change", html_body, text_body)
  end

  def test_observation_destroy_parity
    mary = users(:mary)
    dick = users(:dick)
    observation = observations(:coprinus_comatus_obs)
    note = "**__Coprinus comatus__** L. (123)"

    html_body, text_body = both_bodies(mary) do
      ObservationChangeMailer.build(sender: dick, receiver: mary,
                                    observation: nil, note:,
                                    time: observation.created_at)
    end

    compare("observation_destroy", "observation_destroy", html_body, text_body)
  end

  def test_add_herbarium_record_parity
    rolf = users(:rolf)
    mary = users(:mary)
    herbarium_record = herbarium_records(:interesting_unknown)

    html_body, text_body = both_bodies(rolf) do
      AddHerbariumRecordMailer.build(sender: mary, receiver: rolf,
                                     herbarium_record:)
    end

    compare("add_herbarium_record_not_curator",
            "add_herbarium_record_not_curator", html_body, text_body)
  end

  def test_approval_parity
    mail = ApprovalMailer.build(receiver: katrina, subject: "test subject",
                                message: "test content").message
    fixture_text = body_only(interpolated_fixture("approval.text"))
    assert_equal(normalize_text(fixture_text), normalize_text(mail.body.to_s),
                 "approval TEXT parity mismatch")
  end

  def test_verify_account_parity
    mary = users(:mary)

    html_body, text_body = both_bodies(mary) do
      VerifyAccountMailer.build(receiver: mary)
    end

    compare("verify", "verify", html_body, text_body)
  end

  def test_verify_api_key_parity
    rolf = users(:rolf)
    dick = users(:dick)
    api_key = api_keys(:rolfs_api_key)

    html_body, text_body = both_bodies(rolf) do
      VerifyAPIKeyMailer.build(receiver: rolf, app_user: dick, api_key:)
    end

    compare("verify_api_key", "verify_api_key", html_body, text_body)
  end

  def test_naming_tracker_parity
    mary = users(:mary)
    naming = namings(:agaricus_campestris_naming)

    html_body, text_body = both_bodies(mary) do
      NamingTrackerMailer.build(receiver: mary, naming:)
    end

    compare("naming_for_tracker", "naming_for_tracker", html_body, text_body)
  end

  def test_location_change_parity
    mary = users(:mary)
    dick = users(:dick)
    loc = locations(:albion)
    desc = loc.description

    html_body, text_body = both_bodies(mary) do
      LocationChangeMailer.build(
        sender: dick, receiver: mary, location: loc,
        old_loc_ver: 1, new_loc_ver: 2,
        description: desc, old_desc_ver: 1, new_desc_ver: 2
      )
    end

    compare("location_change", "location_change", html_body, text_body)
  end

  def test_name_change_parity
    mary = users(:mary)
    dick = users(:dick)
    name = names(:peltigera)
    desc = name.description

    html_body, text_body = both_bodies(mary) do
      NameChangeMailer.build(
        sender: dick, receiver: mary, name: name,
        old_name_ver: name.version - 1, new_name_ver: name.version,
        description: desc, old_desc_ver: desc.version - 1,
        new_desc_ver: desc.version, review_status: desc.review_status.to_s
      )
    end

    compare("name_change", "name_change", html_body, text_body)
  end

  def test_name_change2_parity
    mary = users(:mary)
    dick = users(:dick)
    name = names(:peltigera)
    desc = name.description

    mary.update!(email_html: false)
    mail = NameChangeMailer.build(
      sender: dick, receiver: mary, name: name,
      old_name_ver: 0, new_name_ver: 1,
      description: desc, old_desc_ver: 0, new_desc_ver: 1,
      review_status: "no_change"
    ).message
    fixture_text = body_only(interpolated_fixture("name_change2.text"))
    expected = normalize_text(fixture_text)
    actual = mask_ignored_lines(normalize_text(mail.body.to_s), expected)
    assert_equal(expected, actual, "name_change2 TEXT parity mismatch")
  end
end
