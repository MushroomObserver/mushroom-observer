# frozen_string_literal: true

require("test_helper")

# What MO has told a project's admins about (#5416).
class ProjectExternalSiteAlertTest < UnitTestCase
  def setup
    super
    @project = projects(:rare_fungi_project)
    @site = external_sites(:inaturalist)
  end

  def record(id: 999, obs_id: 12_345)
    ProjectExternalSiteAlert.record(
      project: @project, external_site: @site,
      identification: { id: id, name: "Coprinus comatus" },
      observation: { id: obs_id, observed_on: Date.parse("2026-09-20") }
    )
  end

  def test_recording_an_alert
    alert = record

    assert_equal("999", alert.remote_identification_id)
    assert_equal("12345", alert.remote_observation_id)
    assert_equal("Coprinus comatus", alert.name)
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
      observation: { id: 12_345, observed_on: nil }
    )

    assert_not_nil(other)
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
