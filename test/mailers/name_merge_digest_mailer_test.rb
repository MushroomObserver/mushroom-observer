# frozen_string_literal: true

require("test_helper")

class NameMergeDigestMailerTest < MailerTestCase
  def test_build_html_with_observations_and_tracker
    rolf.update!(email_html: true)
    naming = namings(:coprinus_comatus_other_naming)

    mail = build_mail(namings: [naming], tracker_moved: true)

    assert_includes(mail.to, rolf.email)
    assert_html_mail(mail)
    assert_includes(mail.subject, "Old Name merged into")
    body = mail.body.to_s
    assert_includes(body, "#{MO.http_domain}/obs/#{naming.observation_id}")
    assert_includes(body, edit_tracker_url(naming.name))
    assert_includes(body, mary.legal_name)
  end

  def test_build_text_with_observations_only
    rolf.update!(email_html: false)
    naming = namings(:coprinus_comatus_other_naming)

    mail = build_mail(namings: [naming])

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "#{MO.http_domain}/obs/#{naming.observation_id}")
    assert_not_includes(body, :email_name_merge_digest_edit_tracker.l)
  end

  def test_build_text_with_tracker_only
    rolf.update!(email_html: false)
    name = names(:coprinus_comatus)

    mail = build_mail(namings: [], tracker_moved: true, new_name: name)

    assert_includes(mail.body.to_s, edit_tracker_url(name))
    assert_not_includes(mail.body.to_s, "/obs/")
  end

  def test_build_reports_truncation
    rolf.update!(email_html: true)
    naming = namings(:coprinus_comatus_other_naming)

    mail = build_mail(namings: [naming], total_observations: 3)

    assert_includes(
      mail.body.to_s,
      :email_name_merge_digest_truncated.l(shown: 1, count: 3).t
    )
  end

  # A merge run from a script has no user.
  def test_build_without_sender
    rolf.update!(email_html: false)

    mail = build_mail(namings: [namings(:coprinus_comatus_other_naming)],
                      sender: nil)

    assert_includes(mail.body.to_s, :email_name_merge_digest_admin.l)
  end

  private

  def build_mail(namings:, tracker_moved: false, total_observations: nil,
                 new_name: namings.first.name, sender: mary)
    NameMergeDigestMailer.build(
      receiver: rolf, merge: { sender:, old_name: "Old Name", new_name: },
      namings:, total_observations:, tracker_moved:
    ).message
  end

  def edit_tracker_url(name)
    Rails.application.routes.url_helpers.
      edit_tracker_of_name_url(name.id, host: MO.http_domain)
  end
end
