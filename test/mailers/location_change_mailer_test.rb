# frozen_string_literal: true

require("test_helper")

class LocationChangeMailerTest < MailerTestCase
  def test_build_html
    loc = locations(:albion)
    desc = loc.description
    mary.update!(email_html: true)

    mail = LocationChangeMailer.build(
      sender: dick, receiver: mary, location: loc,
      old_loc_ver: 1, new_loc_ver: 2,
      description: desc, old_desc_ver: 1, new_desc_ver: 2
    ).message

    assert_includes(mail.to, mary.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "https://mushroomobserver.org/locations/#{loc.id}")
  end

  def test_build_text
    loc = locations(:albion)
    desc = loc.description
    mary.update!(email_html: false)

    mail = LocationChangeMailer.build(
      sender: dick, receiver: mary, location: loc,
      old_loc_ver: 1, new_loc_ver: 2,
      description: desc, old_desc_ver: 1, new_desc_ver: 2
    ).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "-" * 50)
    assert_includes(body, "https://mushroomobserver.org/locations/#{loc.id}")
  end
end
