# frozen_string_literal: true

require("test_helper")

class ProjectAdministrationMailerTest < MailerTestCase
  def test_build_html
    project = projects(:eol_project)
    rolf.update!(email_html: true)

    mail = ProjectAdministrationMailer.build(site_admin: mary, project:,
                                             receiver: rolf).message

    assert_equal("[MO] #{:email_subject_project_administered.l(
      project: project.title
    )}", mail.subject)
    assert_includes(mail.to, rolf.email)
    assert_equal(mary.email, mail.reply_to.first)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, project.title)
    assert_includes(body,
                    "https://mushroomobserver.org/projects/#{project.id}")
    assert_includes(body, "https://mushroomobserver.org/users/#{mary.id}")
  end

  def test_build_text
    project = projects(:eol_project)
    rolf.update!(email_html: false)

    mail = ProjectAdministrationMailer.build(site_admin: mary, project:,
                                             receiver: rolf).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "-" * 50)
    assert_includes(body,
                    "https://mushroomobserver.org/projects/#{project.id}")
  end
end
