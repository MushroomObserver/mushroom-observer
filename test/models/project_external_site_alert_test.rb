# frozen_string_literal: true

require("test_helper")

# What MO has told a project's admins about (#5416).
class ProjectExternalSiteAlertTest < UnitTestCase
  def setup
    super
    @project = projects(:rare_fungi_project)
    @site = external_sites(:inaturalist)
  end

  def record(id: 999, obs_id: 12_345, target_name: "Coprinus comatus",
             project: @project)
    ProjectExternalSiteAlert.record(
      project: project, external_site: @site,
      identification: { id: id, name: "Coprinus comatus" },
      observation: { id: obs_id, observed_on: Date.parse("2026-09-20") },
      target_name: target_name
    )
  end

  def test_recording_an_alert
    alert = record

    assert_equal("999", alert.remote_identification_id)
    assert_equal("12345", alert.remote_observation_id)
    assert_equal("Coprinus comatus", alert.name)
    assert_equal("Coprinus comatus", alert.target_name)
    assert_equal(Date.parse("2026-09-20"), alert.observed_on)
    assert_not_nil(alert.alerted_at)
  end

  # The unique index is what decides a project has been told, so two
  # cycles running at once cannot both send.
  def test_the_same_identification_records_once_per_project
    record

    assert_nil(record)
    assert_equal(1, ProjectExternalSiteAlert.count)
  end

  def test_another_project_is_told_about_the_same_identification
    record
    other = ProjectExternalSiteAlert.record(
      project: projects(:eol_project), external_site: @site,
      identification: { id: 999, name: "Coprinus comatus" },
      observation: { id: 12_345, observed_on: nil },
      target_name: "Coprinus comatus"
    )

    assert_not_nil(other)
  end

  # The watched name differs from the identified one once a watched
  # genus alerts on its species (#5677).
  def test_the_watched_name_is_recorded
    alert = record(target_name: "Coprinus")

    assert_equal("Coprinus", alert.target_name)
    assert_equal("Coprinus comatus", alert.name)
    assert_equal([ProjectExternalSiteAlert::NEW_OBSERVATION, "Coprinus"],
                 alert.message_key)
  end

  def test_the_first_alert_for_an_observation_is_a_find
    alert = record

    assert_equal(ProjectExternalSiteAlert::NEW_OBSERVATION, alert.kind)
    assert(alert.new_observation?)
  end

  # A confirming or disagreeing identification on an observation the
  # project has heard about is activity, not a find (#5677).
  def test_a_later_identification_on_the_same_observation_is_activity
    record
    alert = record(id: 1000)

    assert_equal(ProjectExternalSiteAlert::OTHER_ACTIVITY, alert.kind)
    assert_not(alert.new_observation?)
  end

  # One project having heard about the observation says nothing about
  # another, which is hearing for the first time.
  def test_another_project_hearing_about_the_observation_is_a_find
    record
    alert = record(id: 1000, project: projects(:eol_project))

    assert_equal(ProjectExternalSiteAlert::NEW_OBSERVATION, alert.kind)
  end

  def test_a_different_observation_is_a_find
    record
    alert = record(id: 1000, obs_id: 12_346)

    assert_equal(ProjectExternalSiteAlert::NEW_OBSERVATION, alert.kind)
  end

  def test_an_unknown_kind_is_rejected
    alert = record
    alert.kind = "something_else"

    assert_not(alert.valid?)
  end

  # The subject line names the watched name and the grouping keys on
  # it, so a row without one has no message to belong to.
  def test_a_missing_watched_name_is_rejected
    alert = record
    alert.target_name = nil

    assert_not(alert.valid?)
  end

  def test_remote_url_points_at_the_observation
    assert_equal("#{Inat::Constants::SITE}/observations/12345",
                 record.remote_url)
  end

  def test_project_destroy_takes_its_alerts
    alert = record
    @project.destroy

    assert_not(ProjectExternalSiteAlert.exists?(alert.id))
  end
end
