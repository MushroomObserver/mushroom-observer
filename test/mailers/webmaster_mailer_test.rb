# frozen_string_literal: true

require("test_helper")

class WebmasterMailerTest < MailerTestCase
  def test_build
    mail = WebmasterMailer.build(sender_email: mary.email,
                                 message: "A question").message

    assert_includes(mail.to, MO.webmaster_email_address)
    assert_equal(mary.email, mail.reply_to.first)
    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "A question")
  end
end
