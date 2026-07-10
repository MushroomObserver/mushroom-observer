# frozen_string_literal: true

require("test_helper")

class CheckOtherRssLogsJobTest < ActiveJob::TestCase
  DANGLING_ID = 999_999_999

  def test_nulls_type_id_on_orphan_notes_for_a_non_observation_type
    log = rss_logs(:name_rss_log)
    log.update_column(:notes, "not a timestamped note\n")

    CheckOtherRssLogsJob.perform_now(verbose: true)

    assert_nil(log.reload.name_id)
  end

  def test_deletes_row_with_bogus_type_id_for_a_non_observation_type
    log = rss_logs(:name_rss_log2)
    log.update_column(:name_id, DANGLING_ID)

    CheckOtherRssLogsJob.perform_now

    assert_not(RssLog.exists?(log.id))
  end

  def test_deletes_ghost_row
    log = rss_logs(:agaricus_campestrus_obs_rss_log)
    log.update_column(:observation_id, nil)

    CheckOtherRssLogsJob.perform_now

    assert_not(RssLog.exists?(log.id))
  end

  # :observation is CheckObservationRssLogsJob's job -- an orphan
  # observation note must survive a run here.
  def test_does_not_check_observation_type
    log = rss_logs(:coprinus_comatus_obs_rss_log)
    log.update_column(:notes, "not a timestamped note\n")

    CheckOtherRssLogsJob.perform_now

    assert_not_nil(log.reload.observation_id)
  end

  def test_perform_runs_end_to_end_without_error
    CheckOtherRssLogsJob.perform_now(verbose: true)
  end
end
