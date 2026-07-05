# frozen_string_literal: true

require("test_helper")

class NamingTrackerMailerTest < MailerTestCase
  def test_build_html
    naming = namings(:agaricus_campestris_naming)
    mary.update!(email_html: true)

    mail = NamingTrackerMailer.build(receiver: mary, naming:).message

    assert_includes(mail.to, mary.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(
      body, "https://mushroomobserver.org/#{naming.observation_id}"
    )
    assert_includes(body, "https://mushroomobserver.org/names/#{naming.name_id}")
  end

  def test_build_text
    naming = namings(:agaricus_campestris_naming)
    mary.update!(email_html: false)

    mail = NamingTrackerMailer.build(receiver: mary, naming:).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s,
                    "https://mushroomobserver.org/#{naming.observation_id}")
  end
end
