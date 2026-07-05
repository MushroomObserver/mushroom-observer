# frozen_string_literal: true

require("test_helper")

class AuthorMailerTest < MailerTestCase
  def test_build_html
    object = names(:coprinus_comatus).description
    rolf.update!(email_html: true)

    mail = AuthorMailer.build(sender: katrina, receiver: rolf, object:,
                              subject: "Please do something or other",
                              message: "and this is why...").message

    assert_includes(mail.to, rolf.email)
    assert_equal(katrina.email, mail.reply_to.first)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "and this is why")
    assert_includes(body,
                    "https://mushroomobserver.org/users/#{katrina.id}")
  end

  def test_build_text
    object = names(:coprinus_comatus).description
    rolf.update!(email_html: false)

    mail = AuthorMailer.build(sender: katrina, receiver: rolf, object:,
                              subject: "Please do something or other",
                              message: "and this is why...").message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "and this is why")
  end
end
