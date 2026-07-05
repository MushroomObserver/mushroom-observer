# frozen_string_literal: true

require("test_helper")

class NamingTrackerMailerTest < MailerTestCase
  def test_build_html
    naming = namings(:agaricus_campestris_naming)
    mary.update!(email_html: true)

    mail = NamingTrackerMailer.build(receiver: mary, naming:).message

    assert_includes(mail.to, mary.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(
      body, "https://mushroomobserver.org/#{naming.observation_id}"
    )
    assert_includes(
      body, "https://mushroomobserver.org/names/#{naming.name_id}"
    )
  end

  def test_build_text
    naming = namings(:agaricus_campestris_naming)
    mary.update!(email_html: false)

    mail = NamingTrackerMailer.build(receiver: mary, naming:).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s,
                    "https://mushroomobserver.org/#{naming.observation_id}")
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

    mail = NamingTrackerMailer.build(receiver: mary, naming:).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "Specimen available")
    assert_includes(body, "https://mushroomobserver.org/users/#{dick.id}")
  end
end
