# frozen_string_literal: true

require("test_helper")

# What MO has told a project's admins about (#5416).
class ProjectAlertTest < UnitTestCase
  def setup
    super
    @project = projects(:rare_fungi_project)
    @site = external_sites(:inaturalist)
  end

  def record(id: 999, obs_id: 12_345, target_name: "Coprinus comatus",
             project: @project)
    ProjectAlert.record(
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
    assert_equal(1, ProjectAlert.count)
  end

  def test_another_project_is_told_about_the_same_identification
    record
    other = ProjectAlert.record(
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
    assert_equal([ProjectAlert::NEW_OBSERVATION, "Coprinus"],
                 alert.message_key)
  end

  def test_the_first_alert_for_an_observation_is_a_find
    alert = record

    assert_equal(ProjectAlert::NEW_OBSERVATION, alert.kind)
    assert(alert.new_observation?)
  end

  # A confirming or disagreeing identification on an observation the
  # project has heard about is activity, not a find (#5677).
  def test_a_later_identification_on_the_same_observation_is_activity
    record
    alert = record(id: 1000)

    assert_equal(ProjectAlert::OTHER_ACTIVITY, alert.kind)
    assert_not(alert.new_observation?)
  end

  # One project having heard about the observation says nothing about
  # another, which is hearing for the first time.
  def test_another_project_hearing_about_the_observation_is_a_find
    record
    alert = record(id: 1000, project: projects(:eol_project))

    assert_equal(ProjectAlert::NEW_OBSERVATION, alert.kind)
  end

  def test_a_different_observation_is_a_find
    record
    alert = record(id: 1000, obs_id: 12_346)

    assert_equal(ProjectAlert::NEW_OBSERVATION, alert.kind)
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

    assert_not(ProjectAlert.exists?(alert.id))
  end

  # --- rows from MO (#5721) --------------------------------------------

  def record_local(observation: observations(:coprinus_comatus_obs),
                   target: nil, project: @project)
    ProjectAlert.record_local(
      project: project, observation: observation,
      target: target || observation, name: "Coprinus comatus",
      target_name: "Coprinus comatus"
    )
  end

  def test_recording_an_alert_from_mo
    obs = observations(:coprinus_comatus_obs)
    alert = record_local

    assert_equal(obs, alert.observation)
    assert_equal(obs, alert.target)
    assert_nil(alert.external_site)
    assert_equal(obs.when, alert.observed_on)
    assert_equal("#{MO.http_domain}/obs/#{obs.id}", alert.url)
    assert_equal(:app_title.l, alert.source_name)
    assert(alert.new_observation?)
  end

  # The unique index on the target is what decides a project has been
  # told, so a second pass over the same record sends nothing.
  def test_the_same_trigger_records_once_per_project
    record_local

    assert_nil(record_local)
    assert_equal(1, ProjectAlert.count)
  end

  # A project told about an observation hears about what happens next
  # as activity.
  def test_a_second_record_on_one_observation_is_activity
    obs = observations(:coprinus_comatus_obs)
    record_local(observation: obs)
    comment = Comment.create!(target: obs, user: users(:rolf),
                              summary: "Note", comment: "Looks right")

    assert_equal(ProjectAlert::OTHER_ACTIVITY,
                 record_local(observation: obs, target: comment).kind)
  end

  # An imported observation that iNaturalist already alerted on is not
  # a find here, whatever happens to it next.
  def test_an_observation_alerted_on_remotely_is_not_a_find_here
    obs = observations(:coprinus_comatus_obs)
    ExternalLink.create!(user: users(:rolf), target: obs,
                         external_site: @site, external_id: "12345")
    record(obs_id: 12_345)

    assert_equal(ProjectAlert::OTHER_ACTIVITY,
                 record_local(observation: obs).kind)
  end

  # A row says what it alerted on, whichever source it came from.
  def test_a_row_naming_no_source_is_rejected
    alert = record_local
    alert.observation = nil

    assert_not(alert.valid?)
  end
end
