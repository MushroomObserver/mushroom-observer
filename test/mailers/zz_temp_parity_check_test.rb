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

  def compare(label, fixture_base, mail_html, mail_text)
    fixture_html = body_only(interpolated_fixture("#{fixture_base}.html"))
    fixture_text = body_only(interpolated_fixture("#{fixture_base}.text"))

    puts("\n#{"=" * 10} #{label} HTML #{"=" * 10}")
    a = normalize_html(fixture_html)
    b = normalize_html(mail_html)
    puts(a == b ? "MATCH" : "MISMATCH\n--fixture--\n#{a}\n--new--\n#{b}")

    puts("\n#{"=" * 10} #{label} TEXT #{"=" * 10}")
    ta = normalize_text(fixture_text)
    tb = normalize_text(mail_text)
    puts(ta == tb ? "MATCH" : "MISMATCH\n--fixture--\n#{ta}\n--new--\n#{tb}")
  end

  def test_comment_parity
    mary = users(:mary)
    rolf = users(:rolf)
    target = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_1)

    mary.update!(email_html: true)
    html_body = CommentMailer.build(sender: rolf, receiver: mary, target:,
                                    comment:).message.body.to_s
    mary.update!(email_html: false)
    text_body = CommentMailer.build(sender: rolf, receiver: mary, target:,
                                    comment:).message.body.to_s

    compare("comment", "comment", html_body, text_body)
  end

  def test_webmaster_parity
    mail = WebmasterMailer.build(sender_email: mary.email,
                                 message: "A question")
    fixture_text = body_only(interpolated_fixture("webmaster_question.text"))
    puts("\n#{"=" * 10} webmaster_question TEXT #{"=" * 10}")
    ta = normalize_text(fixture_text)
    tb = normalize_text(mail.body.to_s)
    puts(ta == tb ? "MATCH" : "MISMATCH\n--fixture--\n#{ta}\n--new--\n#{tb}")
  end

  def test_comment_response_parity
    rolf = users(:rolf)
    dick = users(:dick)
    target = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_2)

    rolf.update!(email_html: true)
    html_body = CommentMailer.build(sender: dick, receiver: rolf, target:,
                                    comment:).message.body.to_s
    rolf.update!(email_html: false)
    text_body = CommentMailer.build(sender: dick, receiver: rolf, target:,
                                    comment:).message.body.to_s

    compare("comment_response", "comment_response", html_body, text_body)
  end
end
