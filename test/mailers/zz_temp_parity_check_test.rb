# frozen_string_literal: true

require("test_helper")

# TEMPORARY — parity check between the golden ERB-era fixtures and
# the new Phlex mailer output. Not a permanent test; keep it around
# while converting the remaining mailers (issue #4676), delete once
# every mailer covered by a fixture has been converted and given its
# own permanent test.
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
    frag.to_html.gsub(/>\s+</, "><").gsub(/\s+/, " ").strip
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

  def compare(label, fixture_base, mail_html, mail_text)
    fixture_html = body_only(interpolated_fixture("#{fixture_base}.html"))
    fixture_text = body_only(interpolated_fixture("#{fixture_base}.text"))

    a = normalize_html(fixture_html)
    b = normalize_html(mail_html)
    assert_equal(a, b, "#{label} HTML parity mismatch")

    ta = normalize_text(fixture_text)
    tb = normalize_text(mail_text)
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
end
