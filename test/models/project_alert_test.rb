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

  # Each observation is its own find: a project that heard about one
  # hears about the next as news, not as activity on the first.
  def test_a_second_observation_from_mo_is_a_find
    record_local(observation: observations(:coprinus_comatus_obs))

    other = observations(:agaricus_campestris_obs)

    assert_equal(ProjectAlert::NEW_OBSERVATION,
                 record_local(observation: other).kind)
  end

  # Sites number their records independently, so the same number from
  # another site is a different observation.
  def test_a_remote_id_from_another_site_is_a_find
    obs = observations(:agaricus_campestris_obs)
    ExternalLink.create!(user: users(:rolf), target: obs,
                         external_site: external_sites(:mycoportal),
                         external_id: "12345")
    record(obs_id: 12_345)

    assert_equal(ProjectAlert::NEW_OBSERVATION,
                 record_local(observation: obs).kind)
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

  # A message groups its rows by the observation they are about, which
  # each source names its way.
  def test_observation_key_names_the_source_copy
    obs = observations(:coprinus_comatus_obs)

    assert_equal([@site.id, "12345"], record.observation_key)
    assert_equal(obs.id, record_local(observation: obs).observation_key)
  end

  # A row says what it alerted on, whichever source it came from.
  def test_a_row_naming_no_source_is_rejected
    alert = record_local
    alert.observation = nil

    assert_not(alert.valid?)
  end

  # What an activity row says, per record and per source. An
  # activity row always follows a find, since that is what makes it
  # activity, so each case is set up with the row before it.
  def test_a_comment_says_so
    obs = observations(:coprinus_comatus_obs)
    reported(obs)

    row = local_activity(obs, comments(:detailed_unknown_obs_comment))

    assert_equal(:email_project_alert_what_comment.l, row.activity_phrase)
  end

  def test_a_naming_of_another_name_says_what_was_proposed
    obs = observations(:coprinus_comatus_obs)
    naming = namings(:coprinus_comatus_naming)
    reported(obs)
    row = local_activity(obs, naming)
    row.update!(name: "Agaricus campestris")

    assert_equal(
      :email_project_alert_what_naming.l(name: naming.name.text_name),
      row.activity_phrase
    )
  end

  def test_a_naming_of_the_name_it_carries_confirms_it
    obs = observations(:coprinus_comatus_obs)
    naming = namings(:coprinus_comatus_naming)
    reported(obs)

    row = local_activity(obs, naming)

    assert_equal(:email_project_alert_what_confirmed.l,
                 row.activity_phrase)
  end

  # The name moved from the one the project was told: a naming of
  # the name the observation carries now, where that is not the
  # name the project heard.
  def test_a_name_that_moved_says_what_it_moved_from
    obs = observations(:coprinus_comatus_obs)
    reported(obs, name: "Helvella palustris")

    row = local_activity(obs, namings(:coprinus_comatus_naming))

    assert_equal(
      :email_project_alert_what_changed_from.l(name: "Helvella palustris"),
      row.activity_phrase
    )
  end

  def test_a_destroyed_naming_still_says_the_name_moved
    obs = observations(:coprinus_comatus_obs)
    naming = namings(:coprinus_comatus_naming)
    reported(obs, name: "Helvella palustris")
    row = local_activity(obs, naming)
    naming.destroy!

    assert_equal(
      :email_project_alert_what_changed_from.l(name: "Helvella palustris"),
      row.reload.activity_phrase
    )
  end

  # Only a naming or an identification confirms a name. A row with
  # neither has nothing to report and reads as it did before, which
  # needs the Observation hook to stop being create-only: today a
  # row targeting the Observation is always the find.
  def test_an_unchanged_name_says_nothing
    obs = observations(:coprinus_comatus_obs)
    reported(obs, target: namings(:coprinus_comatus_naming))

    assert_nil(local_activity(obs, obs).activity_phrase)
  end

  # A site row carries one name, so what the identification did
  # comes from the row before it. A name the project does not watch
  # is flagged, which is the decision the coordinators asked for.
  def test_a_site_row_reads_against_the_row_before_it
    site = external_sites(:inaturalist)
    remote_find(site, name: "Coprinus comatus")

    moved = remote_activity(site, name: "Agaricus campestris")

    assert_equal(
      :email_project_alert_what_changed_from.l(name: "Coprinus comatus"),
      moved.activity_phrase
    )
  end

  def test_a_name_the_project_does_not_watch_is_flagged
    site = external_sites(:inaturalist)
    remote_find(site, name: "Coprinus comatus")

    moved = remote_activity(site, name: "Helvella macropus")

    assert_equal(
      "#{:email_project_alert_what_changed_from.l(
        name: "Coprinus comatus"
      )}, #{:email_project_alert_what_untracked.l}",
      moved.activity_phrase
    )
  end

  def test_an_agreeing_identification_confirms_the_name
    site = external_sites(:inaturalist)
    remote_find(site, name: "Coprinus comatus")

    agreed = remote_activity(site, name: "Coprinus comatus")

    assert_equal(:email_project_alert_what_confirmed.l,
                 agreed.activity_phrase)
  end

  # A provisional code reads as its own shape, and the project does
  # not watch it yet, so the row says so.
  def test_a_provisional_code_reads_as_one
    site = external_sites(:inaturalist)
    remote_find(site, name: "Coprinus comatus")
    code = remote_activity(site, name: "Russula sp-NY01")
    code.update!(provisional: true)

    assert_equal(
      "#{:email_project_alert_what_provisional.l(
        name: "Russula sp-NY01"
      )}, #{:email_project_alert_what_untracked.l}",
      code.activity_phrase
    )
  end

  # A find says an observation arrived; the row adds nothing.
  def test_a_find_has_no_activity_phrase
    obs = observations(:coprinus_comatus_obs)

    assert_nil(reported(obs).activity_phrase)
  end

  # The find this project was told first, which later activity on
  # the same observation reads against. Its target is given, since
  # the unique index on (project, target) allows one row per record:
  # an activity row with an Observation target exists only where the
  # find was raised by a naming or a comment.
  def reported(obs, target: obs, name: nil)
    ProjectAlert.create!(
      project: projects(:rare_fungi_project), observation: obs,
      target: target, name: name || obs.name.text_name,
      target_name: obs.name.text_name,
      kind: ProjectAlert::NEW_OBSERVATION, observed_on: obs.when,
      alerted_at: 1.hour.ago
    )
  end

  def remote_find(site, name:)
    remote_row(site, name: name, ident: "1",
                     kind: ProjectAlert::NEW_OBSERVATION)
  end

  def remote_activity(site, name:)
    remote_row(site, name: name, ident: "2",
                     kind: ProjectAlert::OTHER_ACTIVITY)
  end

  def remote_row(site, name:, ident:, kind:)
    ProjectAlert.create!(
      project: projects(:rare_fungi_project), external_site: site,
      remote_identification_id: ident, remote_observation_id: "12345",
      name: name, target_name: "Coprinus comatus", kind: kind,
      observed_on: Date.parse("2026-09-20"), alerted_at: Time.zone.now
    )
  end

  def local_activity(obs, target)
    ProjectAlert.create!(
      project: projects(:rare_fungi_project), observation: obs,
      target: target, name: obs.name.text_name,
      target_name: obs.name.text_name,
      kind: ProjectAlert::OTHER_ACTIVITY, observed_on: obs.when,
      alerted_at: Time.zone.now
    )
  end
end
