# frozen_string_literal: true

require("test_helper")

class CheckForBrokenReferencesJobTest < ActiveJob::TestCase
  DANGLING_ID = 999_999_999

  def test_delete_action_removes_dangling_row
    key = api_keys(:rolfs_api_key)
    key.update_column(:user_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now

    assert_not(APIKey.exists?(key.id))
  end

  def test_nil_action_nulls_dangling_column
    list = species_lists(:first_species_list)
    list.update_column(:location_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now

    assert_nil(list.reload.location_id)
  end

  def test_zero_action_zeroes_dangling_column
    article = articles(:premier_article)
    article.update_column(:user_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now

    assert_equal(0, article.reload.user_id)
  end

  def test_alert_action_only_reports_does_not_modify
    coll_num = collection_numbers(:minimal_unknown_coll_num)
    coll_num.update_column(:user_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now

    assert_equal(DANGLING_ID, coll_num.reload.user_id,
                 ":alert should report, not modify, the dangling reference")
  end

  def test_polymorphic_action_deletes_dangling_row
    interest = interests(:detailed_unknown_obs_interest)
    interest.update_column(:target_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now

    assert_not(Interest.exists?(interest.id))
  end

  def test_dry_run_reports_without_modifying
    key = api_keys(:rolfs_api_key)
    key.update_column(:user_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now(dry_run: true)

    assert(APIKey.exists?(key.id),
           "dry_run should not delete the dangling row")
  end

  def test_stale_monomorphic_check_logs_instead_of_raising
    job = CheckForBrokenReferencesJob.new
    job.instance_variable_set(:@dry_run, true)
    job.instance_variable_set(:@verbose, false)
    job.instance_variable_set(:@reflections, {})

    job.send(:check_monomorphic, APIKey, :no_such_association, :delete)
  end

  def test_stale_polymorphic_check_logs_instead_of_raising
    job = CheckForBrokenReferencesJob.new
    job.instance_variable_set(:@dry_run, true)
    job.instance_variable_set(:@verbose, false)
    job.instance_variable_set(:@reflections, {})

    job.send(:check_polymorphic, APIKey, Observation)
  end

  def test_invalid_action_raises
    job = CheckForBrokenReferencesJob.new
    job.instance_variable_set(:@dry_run, true)

    assert_raises(RuntimeError) do
      job.send(:apply_action, APIKey, :user_id, APIKey.none, [1],
               :bogus_action)
    end
  end

  def test_model_from_file_rescues_unconstantizable_filename
    job = CheckForBrokenReferencesJob.new

    assert_nil(job.send(:model_from_file, "totally_not_a_real_model.rb"))
  end

  def test_perform_runs_end_to_end_without_error
    CheckForBrokenReferencesJob.perform_now(verbose: true)
  end

  # A dangling :alert reference produces exactly one summary alert for the
  # whole run, naming the offending table.column.
  def test_emits_one_review_alert_for_dangling_alert_reference
    coll_num = collection_numbers(:minimal_unknown_coll_num)
    coll_num.update_column(:user_id, DANGLING_ID)

    alerts = capture_alerts { CheckForBrokenReferencesJob.perform_now }

    assert_equal(1, alerts.size, "expected exactly one summary alert per run")
    assert_instance_of(JobAlert, alerts.first)
    assert_includes(alerts.first.message, "collection_numbers.user_id")
  end

  # emit_review_summary is the "at most one alert per run" choke point:
  # nothing to review => no alert, so a quiet week stays silent.
  def test_no_alert_when_run_finds_nothing_to_review
    job = CheckForBrokenReferencesJob.new
    job.instance_variable_set(:@review_findings, [])

    alerts = capture_alerts { job.send(:emit_review_summary) }

    assert_empty(alerts, "a run with no findings should emit no alert")
  end

  # Multiple findings in one run collapse into a single summary alert.
  def test_multiple_findings_collapse_into_one_summary_alert
    job = CheckForBrokenReferencesJob.new
    job.instance_variable_set(:@review_findings,
                              ["dangling foo.bar", "STALE CHECK: Baz.qux"])

    alerts = capture_alerts { job.send(:emit_review_summary) }

    assert_equal(1, alerts.size)
    assert_includes(alerts.first.message, "2 reference issue")
    assert_includes(alerts.first.message, "dangling foo.bar")
    assert_includes(alerts.first.message, "STALE CHECK: Baz.qux")
  end

  # A reflection left uncovered by the Checks lists (val stays :need) is
  # logged AND flagged for the #alerts summary.
  def test_missing_reflection_is_logged_and_flagged_for_review
    job = CheckForBrokenReferencesJob.new
    logged = []
    job.define_singleton_method(:log) { |msg| logged << msg }
    job.instance_variable_set(:@reflections, { "Foo.bar" => :need })
    job.instance_variable_set(:@review_findings, [])

    job.send(:report_missing_reflections)

    assert_includes(logged, "MISSING REFLECTION Foo.bar")
    assert_includes(job.instance_variable_get(:@review_findings),
                    "MISSING REFLECTION: Foo.bar")
  end

  # Guards against model drift: every belongs_to must be covered by
  # Checks::MONOMORPHIC/POLYMORPHIC (or be a typed view of a polymorphic
  # target, which discovery skips). A new/renamed/removed association that
  # isn't reflected in the lists should fail here, not crash the production
  # run - which is exactly what happened when ExternalLink/FieldSlip dropped
  # their observation_id.
  def test_every_belongs_to_is_covered_or_stale_free
    job = CheckForBrokenReferencesJob.new
    logged = []
    job.define_singleton_method(:log) { |msg| logged << msg }
    job.perform(dry_run: true)

    assert_empty(logged.grep(/MISSING REFLECTION/),
                 "Uncovered belongs_to - add to " \
                 "CheckForBrokenReferencesJob::Checks:\n" \
                 "#{logged.grep(/MISSING REFLECTION/).join("\n")}")
    assert_empty(logged.grep(/STALE CHECK/),
                 "Check list names associations that no longer exist:\n" \
                 "#{logged.grep(/STALE CHECK/).join("\n")}")
  end

  private

  # Records the exceptions handed to the #alerts pipeline while alerting is
  # forced active, so tests can assert on what a run would post to Slack.
  def capture_alerts(&block)
    alerts = []
    ExceptionNotifier.stub(:notifiers, [:slack]) do
      ExceptionNotifier.stub(:notify_exception,
                             lambda { |exception, **_o|
                               alerts << exception
                             }, &block)
    end
    alerts
  end
end
