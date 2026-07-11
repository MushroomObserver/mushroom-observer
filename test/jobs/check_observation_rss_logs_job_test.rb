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

    CheckObservationRssLogsJob.perform_now(verbose: true)

    assert_nil(log.reload.observation_id)
  end

  # Regression test for the "landmine" bug (GitHub issue #4763): roughly
  # 845 observations were falsely orphaned by a 2016 mass-deletion
  # malfunction and are still live. A log whose notes look orphaned but
  # whose target still exists must be left alone -- nulling its type_id
  # would sever the live observation's only link back to its own history.
  def test_does_not_null_type_id_when_target_is_still_alive
    log = rss_logs(:agaricus_campestras_obs_rss_log)
    log.update_column(:notes, "not a timestamped note\n")

    CheckObservationRssLogsJob.perform_now(verbose: true)

    assert_not_nil(log.reload.observation_id)
  end

  def test_deletes_row_with_bogus_type_id
    log = rss_logs(:agaricus_campestris_obs_rss_log)
    log.update_column(:observation_id, DANGLING_ID)

    CheckObservationRssLogsJob.perform_now

    assert_not(RssLog.exists?(log.id))
  end

  def test_dry_run_reports_without_modifying
    log = rss_logs(:coprinus_comatus_obs_rss_log)
    log.update_column(:notes, "not a timestamped note\n")
    log.observation.delete

    CheckObservationRssLogsJob.perform_now(dry_run: true)

    assert_not_nil(log.reload.observation_id)
  end

  # This job doesn't run the ghost check (see CheckOtherRssLogsJob) --
  # a would-be ghost row (every type_id nil) must survive a run here.
  def test_does_not_delete_ghost_rows
    log = rss_logs(:agaricus_campestrus_obs_rss_log)
    log.update_column(:observation_id, nil)

    CheckObservationRssLogsJob.perform_now

    assert(RssLog.exists?(log.id))
  end

  def test_perform_runs_end_to_end_without_error
    CheckObservationRssLogsJob.perform_now(verbose: true)
  end
end
