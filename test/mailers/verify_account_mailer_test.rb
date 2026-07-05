# frozen_string_literal: true

require("test_helper")

class VerifyAccountMailerTest < MailerTestCase
  def test_build_html
    mary.update!(email_html: true)

    mail = VerifyAccountMailer.build(receiver: mary).message

    assert_includes(mail.to, mary.email)
    assert_equal(MO.accounts_email_address, mail.from.first)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body,
                    "https://mushroomobserver.org/account/verify/#{mary.id}")
  end

  def test_build_text
    mary.update!(email_html: false)

    mail = VerifyAccountMailer.build(receiver: mary).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s,
                    "https://mushroomobserver.org/account/verify/#{mary.id}")
  end
end
