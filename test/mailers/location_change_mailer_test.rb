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

  # ONE_LINER_FIELDS previously mislabeled the low-elevation line with
  # the :show_location_highest key (copy-paste from the high-elevation
  # row above it) — rendered directly against a fabricated loc_change
  # since it's simpler than hunting for real version history where
  # only `low` differs.
  def test_low_elevation_change_uses_lowest_label
    old_loc = Location.find(locations(:albion).id)
    old_loc.low = 0.0
    new_loc = Location.find(locations(:albion).id)
    new_loc.low = 50.0

    html = render(Views::Mailers::LocationChangeMailer::Text.new(
                    subject: "test", receiver: rolf, sender: dick,
                    time: Time.zone.now,
                    loc_change: fake_change(old_loc, new_loc),
                    desc_change: fake_change(nil, nil),
                    watching: false, email_type: nil
                  ))

    assert_includes(html, :show_location_lowest.l)
  end

  # PERMISSION_REASONS checks admin before editor/author — a receiver
  # qualifying for multiple reasons should be reported as "admin" so
  # the "stop sending" link they see actually stops the notification,
  # rather than leaving them still subscribed via the narrower role.
  def test_build_desc_only_change_admin_wins_over_editor
    loc = locations(:albion)
    desc = loc.description
    desc.admin_groups << UserGroup.one_user(dick)
    desc.add_editor(dick)
    dick.update!(email_locations_admin: true, email_locations_editor: true,
                 email_html: false)

    mail = LocationChangeMailer.build(
      sender: rolf, receiver: dick, location: loc,
      old_loc_ver: loc.version, new_loc_ver: loc.version,
      description: desc, old_desc_ver: desc.version - 1,
      new_desc_ver: desc.version
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "type=locations_admin")
  end

  private

  def fake_change(old_clone, new_clone)
    change = ObjectChange.allocate
    change.instance_variable_set(:@old_clone, old_clone)
    change.instance_variable_set(:@new_clone, new_clone)
    change
  end
end
