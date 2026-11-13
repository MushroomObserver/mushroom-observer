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

  def find_subject_one
    :email_subject_project_alert_find_one.l(name: "Coprinus comatus",
                                            site: @site.name)
  end

  def alert(**args)
    ProjectExternalSiteAlert.create!(
      { project: @project, external_site: @site,
        remote_identification_id: "999", remote_observation_id: "12345",
        name: "Coprinus comatus", target_name: "Coprinus comatus",
        kind: ProjectExternalSiteAlert::NEW_OBSERVATION,
        observed_on: Date.parse("2026-09-20"),
        alerted_at: Time.zone.now }.merge(args)
    )
  end

  def test_html_digest
    mary.update!(email_html: true)

    mail = ProjectAlertMailer.build(receiver: mary, alerts: [alert]).message

    assert_equal("[MO] #{find_subject_one}", mail.subject)
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

    assert_equal(
      "[MO] #{:email_subject_project_alert_find.l(
        name: "Coprinus comatus", site: @site.name
      )}",
      mail.subject
    )
    body = mail.body.to_s

    assert_includes(body, "Coprinus comatus")
    assert_includes(body, "Agaricus campestris")
  end

  # The subject names the watched name and whether this is a find or
  # later activity, which is what says how soon to follow it up
  # (#5677). The count and the projects stay in the body.
  def test_an_activity_message_says_so
    alerts = [alert(kind: ProjectExternalSiteAlert::OTHER_ACTIVITY)]

    mail = ProjectAlertMailer.build(receiver: mary, alerts: alerts).message

    assert_equal(
      "[MO] #{:email_subject_project_alert_activity_one.l(
        name: "Coprinus comatus", site: @site.name
      )}",
      mail.subject
    )
    assert_includes(mail.body.to_s, @project.title)
  end

  def test_activity_on_several_observations
    alerts = [alert(kind: ProjectExternalSiteAlert::OTHER_ACTIVITY),
              alert(kind: ProjectExternalSiteAlert::OTHER_ACTIVITY,
                    remote_identification_id: "1000",
                    remote_observation_id: "12346")]

    mail = ProjectAlertMailer.build(receiver: mary, alerts: alerts).message

    assert_equal(
      "[MO] #{:email_subject_project_alert_activity.l(
        name: "Coprinus comatus", site: @site.name
      )}",
      mail.subject
    )
  end

  # A watched genus alerts on its species, and the message is about the
  # name the project entered (#5677).
  def test_a_species_reported_under_the_watched_genus
    alerts = [alert(name: "Coprinus comatus", target_name: "Coprinus")]

    mail = ProjectAlertMailer.build(receiver: mary, alerts: alerts).message
    body = mail.body.to_s

    assert_equal(
      "[MO] #{:email_subject_project_alert_find_one.l(name: "Coprinus",
                                                      site: @site.name)}",
      mail.subject
    )
    assert_includes(body, "Coprinus comatus")
  end

  # One observation can match several of the receiver's projects. They
  # read about it once, with both projects named on the row.
  def test_an_observation_matching_two_projects_is_one_row
    # Text, so the link counts once per row rather than as href and
    # link text both.
    mary.update!(email_html: false)
    other = projects(:bolete_project)
    alerts = [alert,
              alert(project: other, remote_identification_id: "1001")]

    mail = ProjectAlertMailer.build(receiver: mary, alerts: alerts).message

    assert_equal("[MO] #{find_subject_one}", mail.subject)
    body = mail.body.to_s

    assert_includes(body, @project.title)
    assert_includes(body, other.title)
    assert_equal(1, body.scan("/observations/12345").size)
  end

  # Newest observation first, with the undated ones after -- the recent
  # find is the one an admin may still be able to do something about.
  def test_rows_run_newest_first_with_undated_last
    alerts = [
      alert(observed_on: nil, remote_identification_id: "1002",
            remote_observation_id: "12347", name: "Gomphus clavatus"),
      alert(observed_on: Date.parse("2026-09-20")),
      alert(observed_on: Date.parse("2026-09-21"),
            remote_identification_id: "1001",
            remote_observation_id: "12346", name: "Entoloma luteum")
    ]

    body = ProjectAlertMailer.build(receiver: mary,
                                    alerts: alerts).message.body.to_s
    # By link, not by name: the intro names the watched name too.
    order = %w[12346 12345 12347].
            map { |obs_id| body.index("/observations/#{obs_id}") }

    assert_equal(order.sort, order)
    assert_includes(body, "date unknown")
  end
end
