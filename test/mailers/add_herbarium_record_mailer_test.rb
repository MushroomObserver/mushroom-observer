# frozen_string_literal: true

require("test_helper")

class AddHerbariumRecordMailerTest < MailerTestCase
  def test_build_html
    herbarium_record = herbarium_records(:interesting_unknown)
    rolf.update!(email_html: true)

    mail = AddHerbariumRecordMailer.build(sender: mary, receiver: rolf,
                                          herbarium_record:).message

    assert_includes(mail.to, rolf.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, herbarium_record.herbarium.name)
    assert_includes(body, herbarium_record.herbarium_label)
    assert_includes(
      body,
      "https://mushroomobserver.org/herbarium_records/#{herbarium_record.id}"
    )
    assert_includes(
      body,
      "https://mushroomobserver.org/herbaria/#{herbarium_record.herbarium.id}"
    )
    assert_includes(body, "https://mushroomobserver.org/users/#{mary.id}")
  end

  def test_build_text
    herbarium_record = herbarium_records(:interesting_unknown)
    rolf.update!(email_html: false)

    mail = AddHerbariumRecordMailer.build(sender: mary, receiver: rolf,
                                          herbarium_record:).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, herbarium_record.herbarium.name)
    assert_includes(body, herbarium_record.herbarium_label)
  end
end
