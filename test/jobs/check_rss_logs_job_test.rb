# frozen_string_literal: true

require("test_helper")

class CheckRssLogsJobTest < ActiveJob::TestCase
  DANGLING_ID = 999_999_999

  def test_nulls_type_id_on_orphan_notes
    log = rss_logs(:coprinus_comatus_obs_rss_log)
    log.update_column(:notes, "not a timestamped note\n")

    CheckRssLogsJob.perform_now(verbose: true)

    assert_nil(log.reload.observation_id)
  end

  def test_deletes_row_with_bogus_type_id
    log = rss_logs(:agaricus_campestris_obs_rss_log)
    log.update_column(:observation_id, DANGLING_ID)

    CheckRssLogsJob.perform_now

    assert_not(RssLog.exists?(log.id))
  end

  def test_deletes_ghost_row
    log = rss_logs(:agaricus_campestrus_obs_rss_log)
    log.update_column(:observation_id, nil)

    CheckRssLogsJob.perform_now

    assert_not(RssLog.exists?(log.id))
  end

  def test_dry_run_reports_without_modifying
    log = rss_logs(:agaricus_campestras_obs_rss_log)
    log.update_column(:notes, "not a timestamped note\n")

    CheckRssLogsJob.perform_now(dry_run: true)

    assert_not_nil(log.reload.observation_id)
  end

  def test_perform_runs_end_to_end_without_error
    CheckRssLogsJob.perform_now(verbose: true)
  end
end
