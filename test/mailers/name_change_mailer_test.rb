# frozen_string_literal: true

require("test_helper")

class NameChangeMailerTest < MailerTestCase
  def test_build_change_html
    name = names(:peltigera)
    desc = name.description
    mary.update!(email_html: true)

    mail = NameChangeMailer.build(
      sender: dick, receiver: mary, name:,
      old_name_ver: name.version - 1, new_name_ver: name.version,
      description: desc, old_desc_ver: desc.version - 1,
      new_desc_ver: desc.version, review_status: desc.review_status.to_s
    ).message

    assert_includes(mail.to, mary.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "https://mushroomobserver.org/names/#{name.id}")
  end

  def test_build_change_text
    name = names(:peltigera)
    desc = name.description
    mary.update!(email_html: false)

    mail = NameChangeMailer.build(
      sender: dick, receiver: mary, name:,
      old_name_ver: name.version - 1, new_name_ver: name.version,
      description: desc, old_desc_ver: desc.version - 1,
      new_desc_ver: desc.version, review_status: desc.review_status.to_s
    ).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "-" * 50)
    assert_includes(body, "https://mushroomobserver.org/names/#{name.id}")
  end

  def test_build_new_name_text
    name = names(:peltigera)
    desc = name.description
    mary.update!(email_html: false)

    mail = NameChangeMailer.build(
      sender: dick, receiver: mary, name:,
      old_name_ver: 0, new_name_ver: 1,
      description: desc, old_desc_ver: 0, new_desc_ver: 1,
      review_status: "no_change"
    ).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "was created")
    assert_includes(body, "https://mushroomobserver.org/names/#{name.id}")
  end
end
