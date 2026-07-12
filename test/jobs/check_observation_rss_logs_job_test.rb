# frozen_string_literal: true

require("test_helper")

class CheckObservationRssLogsJobTest < ActiveJob::TestCase
  DANGLING_ID = 999_999_999

  def test_nulls_type_id_on_orphan_notes_when_target_is_gone
    log = rss_logs(:coprinus_comatus_obs_rss_log)
    log.update_column(:notes, "not a timestamped note\n")
    # `.delete`, not `.destroy` -- bypasses callbacks so the observation
    # is simply gone without RssLog#orphan properly clearing
    # observation_id first. That mismatch (target gone, type_id still
    # set) is exactly the anomaly this job exists to clean up.
    log.observation.delete

    alerts = capture_alerts do
      CheckObservationRssLogsJob.perform_now(verbose: true)
    end

    assert_nil(log.reload.observation_id)
    assert_includes(alerts.first.message, "nulled observation_id")
    assert_includes(alerts.first.message, log.id.to_s)
  end

  # Regression test for the "landmine" bug (GitHub issue #4763): roughly
  # 845 observations were falsely orphaned by a 2016 mass-deletion
  # malfunction and are still live. A log whose notes look orphaned but
  # whose target still exists must be left alone -- nulling its type_id
  # would sever the live observation's only link back to its own history.
  # Nothing changes, so it must not alert.
  def test_does_not_null_type_id_when_target_is_still_alive
    log = rss_logs(:agaricus_campestras_obs_rss_log)
    log.update_column(:notes, "not a timestamped note\n")

    alerts = capture_alerts do
      CheckObservationRssLogsJob.perform_now(verbose: true)
    end

    assert_not_nil(log.reload.observation_id)
    assert_empty(alerts)
  end

  def test_deletes_row_with_bogus_type_id
    log = rss_logs(:agaricus_campestris_obs_rss_log)
    log.update_column(:observation_id, DANGLING_ID)

    alerts = capture_alerts { CheckObservationRssLogsJob.perform_now }

    assert_not(RssLog.exists?(log.id))
    assert_includes(alerts.first.message, "bogus observation_id")
    assert_includes(alerts.first.message, log.id.to_s)
  end

  def test_dry_run_reports_without_modifying_or_alerting
    log = rss_logs(:coprinus_comatus_obs_rss_log)
    log.update_column(:notes, "not a timestamped note\n")
    log.observation.delete

    alerts = capture_alerts do
      CheckObservationRssLogsJob.perform_now(dry_run: true)
    end

    assert_not_nil(log.reload.observation_id)
    assert_empty(alerts)
  end

  # This job doesn't run the ghost check (see CheckOtherRssLogsJob) --
  # a would-be ghost row (every type_id nil) must survive a run here,
  # and nothing changes, so it must not alert.
  def test_does_not_delete_ghost_rows
    log = rss_logs(:agaricus_campestrus_obs_rss_log)
    log.update_column(:observation_id, nil)

    alerts = capture_alerts { CheckObservationRssLogsJob.perform_now }

    assert(RssLog.exists?(log.id))
    assert_empty(alerts)
  end

  def test_perform_runs_end_to_end_without_error
    CheckObservationRssLogsJob.perform_now(verbose: true)
  end

  private

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
