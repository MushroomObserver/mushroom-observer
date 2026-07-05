# frozen_string_literal: true

require("test_helper")

class UserQuestionMailerTest < MailerTestCase
  def test_build_html
    mary.update!(email_html: true)

    mail = UserQuestionMailer.build(
      sender: rolf, receiver: mary, subject: "Interesting idea",
      message: "Shall we discuss it in email?"
    ).message

    assert_includes(mail.to, mary.email)
    assert_equal(rolf.email, mail.reply_to.first)
    assert_html_mail(mail)
    assert_includes(mail.body.to_s, "Shall we discuss it in email?")
  end

  def test_build_text
    mary.update!(email_html: false)

    mail = UserQuestionMailer.build(
      sender: rolf, receiver: mary, subject: "Interesting idea",
      message: "Shall we discuss it in email?"
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "Shall we discuss it in email?")
  end
end
