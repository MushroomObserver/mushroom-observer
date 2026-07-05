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

  # Location version unchanged, only the description changed — hits
  # the `elsif (new_desc = desc_change.new_clone)` branch of
  # location_email_type, distinct from both test_build_html/text's
  # "location itself changed" branch. rolf is albion's description
  # author and has email_locations_author on, so this also confirms
  # permission_reason resolves to "author" (not left un-notified).
  def test_build_desc_only_change
    loc = locations(:albion)
    desc = loc.description
    rolf.update!(email_html: false)

    mail = LocationChangeMailer.build(
      sender: dick, receiver: rolf, location: loc,
      old_loc_ver: loc.version, new_loc_ver: loc.version,
      description: desc, old_desc_ver: desc.version - 1,
      new_desc_ver: desc.version
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "type=locations_author")
  end
end
