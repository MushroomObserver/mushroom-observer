# frozen_string_literal: true

require("test_helper")

class ApprovalMailerTest < MailerTestCase
  def test_build
    mail = ApprovalMailer.build(receiver: katrina, subject: "test subject",
                                message: "test content").message

    assert_includes(mail.to, katrina.email)
    assert_equal(MO.webmaster_email_address, mail.reply_to.first)
    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "test content")
  end
end
