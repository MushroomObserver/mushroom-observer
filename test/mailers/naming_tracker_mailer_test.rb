# frozen_string_literal: true

require("test_helper")

class NamingTrackerMailerTest < MailerTestCase
  def routes
    Rails.application.routes.url_helpers
  end

  def mary_tracker
    name_trackers(:agaricus_campestris_name_tracker_with_note)
  end

  def test_build_html
    naming = namings(:agaricus_campestris_naming)
    mary.update!(email_html: true)

    mail = NamingTrackerMailer.build(
      receiver: mary, naming:, name_tracker: mary_tracker
    ).message

    assert_includes(mail.to, mary.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_html(
      body,
      "a[href='https://mushroomobserver.org/obs/#{naming.observation_id}']"
    )
    assert_html(
      body, "a[href='https://mushroomobserver.org/names/#{naming.name_id}']"
    )
    assert_html(
      body, "a[href='#{MO.http_domain}" \
            "#{routes.edit_tracker_of_name_path(mary_tracker.name_id)}']"
    )
  end

  def test_build_text
    naming = namings(:agaricus_campestris_naming)
    mary.update!(email_html: false)

    mail = NamingTrackerMailer.build(
      receiver: mary, naming:, name_tracker: mary_tracker
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s,
                    "https://mushroomobserver.org/obs/#{naming.observation_id}")
  end

  # Covers specimen_line's "available" branch (fixture's observation
  # otherwise has specimen: false) and identifier_link's
  # non-empty-array branch (fixture's naming and observation
  # otherwise share the same user, so identifier_link normally
  # short-circuits to []).
  def test_build_specimen_available_and_identifier_shown
    naming = namings(:agaricus_campestris_naming)
    naming.observation.update!(specimen: true)
    naming.update!(user: dick)
    mary.update!(email_html: false)

    mail = NamingTrackerMailer.build(
      receiver: mary, naming:, name_tracker: mary_tracker
    ).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "Specimen available")
    assert_includes(body, "https://mushroomobserver.org/users/#{dick.id}")
  end

  # A genus tracker fires on a species naming; the disable link must point
  # at the tracked genus, not the proposed species.
  def test_disable_link_targets_tracked_name
    naming = namings(:agaricus_campestris_naming)
    genus = names(:agaricus)
    tracker = NameTracker.create!(user: mary, name: genus)
    mary.update!(email_html: false)

    mail = NamingTrackerMailer.build(
      receiver: mary, naming:, name_tracker: tracker
    ).message

    body = mail.body.to_s
    assert_includes(
      body, "#{MO.http_domain}#{routes.edit_tracker_of_name_path(genus.id)}",
      "Disable-tracking link should edit the tracker on the tracked Name"
    )
    assert_not_includes(
      body, "email_tracking",
      "Disable-tracking link should not use the removed email_tracking route"
    )
  end
end
