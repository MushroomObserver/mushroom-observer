# frozen_string_literal: true

require("test_helper")

class ProjectAdminRequestMailerTest < MailerTestCase
  def test_build_html
    project = projects(:eol_project)
    rolf.update!(email_html: true)

    mail = ProjectAdminRequestMailer.build(
      sender: katrina, receiver: rolf, project:,
      subject: "Please do something or other", message: "and this is why..."
    ).message

    assert_includes(mail.to, rolf.email)
    assert_equal(katrina.email, mail.reply_to.first)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, project.title)
    assert_includes(body, "and this is why")
  end

  def test_build_text
    project = projects(:eol_project)
    rolf.update!(email_html: false)

    mail = ProjectAdminRequestMailer.build(
      sender: katrina, receiver: rolf, project:,
      subject: "Please do something or other", message: "and this is why..."
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "and this is why")
  end
end
