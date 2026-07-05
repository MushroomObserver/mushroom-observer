# frozen_string_literal: true

require("test_helper")

class ObserverQuestionMailerTest < MailerTestCase
  def test_build_html
    observation = observations(:detailed_unknown_obs)
    observation.user.update!(email_html: true)

    mail = ObserverQuestionMailer.build(
      sender: rolf, observation:, message: "Where did you find it?"
    ).message

    assert_includes(mail.to, observation.user.email)
    assert_equal(rolf.email, mail.reply_to.first)
    assert_html_mail(mail)
    assert_includes(mail.body.to_s, "Where did you find it?")
  end

  def test_build_text
    observation = observations(:detailed_unknown_obs)
    observation.user.update!(email_html: false)

    mail = ObserverQuestionMailer.build(
      sender: rolf, observation:, message: "Where did you find it?"
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "Where did you find it?")
  end
end
