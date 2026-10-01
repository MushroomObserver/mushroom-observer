# frozen_string_literal: true

require("test_helper")

# One digest per project admin per cycle, naming what iNaturalist newly
# identified as something the project watches (#5416).
class ProjectAlertMailerTest < MailerTestCase
  def setup
    super
    @project = projects(:rare_fungi_project)
    @site = external_sites(:inaturalist)
  end

  def alert(**args)
    ProjectExternalSiteAlert.create!(
      { project: @project, external_site: @site,
        remote_identification_id: "999", remote_observation_id: "12345",
        name: "Coprinus comatus", observed_on: Date.parse("2026-09-20"),
        alerted_at: Time.zone.now }.merge(args)
    )
  end

  def test_html_digest
    mary.update!(email_html: true)

    mail = ProjectAlertMailer.build(receiver: mary, alerts: [alert]).message

    assert_equal("[MO] #{:email_subject_project_alert_one.l(count: 1)}",
                 mail.subject)
    assert_includes(mail.to, mary.email)
    assert_html_mail(mail)
    body = mail.body.to_s

    # The row names the project the observation matched.
    assert_includes(body, @project.title)
    assert_includes(body, "Coprinus comatus")
    assert_includes(body, Date.parse("2026-09-20").web_date)
    assert_includes(body, "#{Inat::Constants::SITE}/observations/12345")
    # Rows are a list, not loose <li>s.
    assert_match(%r{<ul>.*<li>.*</li>.*</ul>}m, body)
    # emit_tp textilizes, so the view hands it a localized string.
    assert_no_match(/<div class="textile"><div class="textile">/, body)
  end

  def test_text_digest
    mary.update!(email_html: false)

    mail = ProjectAlertMailer.build(receiver: mary, alerts: [alert]).message

    assert_text_mail(mail)
    body = mail.body.to_s

    assert_includes(body, "Coprinus comatus")
    assert_includes(body, "#{Inat::Constants::SITE}/observations/12345")
  end

  # An observation iNat gives no date for still says what was applied.
  def test_an_alert_without_a_date
    mail = ProjectAlertMailer.build(
      receiver: mary, alerts: [alert(observed_on: nil)]
    ).message

    assert_includes(mail.body.to_s, :unknown.l)
  end

  def test_several_alerts_are_one_message
    others = [alert, alert(remote_identification_id: "1000",
                           remote_observation_id: "12346",
                           name: "Agaricus campestris")]

    mail = ProjectAlertMailer.build(receiver: mary, alerts: others).message

    assert_equal("[MO] #{:email_subject_project_alert.l(count: 2)}",
                 mail.subject)
    body = mail.body.to_s

    assert_includes(body, "Coprinus comatus")
    assert_includes(body, "Agaricus campestris")
  end

  # One observation can match several of the receiver's projects. They
  # read about it once, with both projects named on the row.
  def test_an_observation_matching_two_projects_is_one_row
    other = projects(:bolete_project)
    alerts = [alert,
              alert(project: other, remote_identification_id: "1001")]

    mail = ProjectAlertMailer.build(receiver: mary, alerts: alerts).message

    assert_equal("[MO] #{:email_subject_project_alert_one.l(count: 1)}",
                 mail.subject)
    body = mail.body.to_s

    assert_includes(body, @project.title)
    assert_includes(body, other.title)
    assert_equal(1, body.scan("Coprinus comatus").size)
  end
end
