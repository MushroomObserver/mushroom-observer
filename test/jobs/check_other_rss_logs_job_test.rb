# frozen_string_literal: true

require("test_helper")

class CheckOtherRssLogsJobTest < ActiveJob::TestCase
  DANGLING_ID = 999_999_999

  def test_nulls_type_id_on_orphan_notes_for_a_non_observation_type
    log = rss_logs(:name_rss_log)
    log.update_column(:notes, "not a timestamped note\n")
    # `.delete`, not `.destroy` -- bypasses callbacks so the name is
    # simply gone without RssLog#orphan properly clearing name_id
    # first. See CheckObservationRssLogsJobTest for the same pattern.
    log.name.delete

    alerts = capture_alerts { CheckOtherRssLogsJob.perform_now(verbose: true) }

    assert_nil(log.reload.name_id)
    assert_includes(alerts.first.message, "nulled name_id")
    assert_includes(alerts.first.message, log.id.to_s)
  end

  # Regression test for the "landmine" bug (GitHub issue #4763) for a
  # non-observation type -- see CheckObservationRssLogsJobTest for the
  # full explanation. A log whose notes look orphaned but whose target
  # still exists must be left alone -- and, since nothing changed, must
  # not alert.
  def test_does_not_null_type_id_when_target_is_still_alive
    log = rss_logs(:name_rss_log2)
    log.update_column(:notes, "not a timestamped note\n")

    alerts = capture_alerts { CheckOtherRssLogsJob.perform_now(verbose: true) }

    assert_not_nil(log.reload.name_id)
    assert_empty(alerts)
  end

  def test_deletes_row_with_bogus_type_id_for_a_non_observation_type
    log = rss_logs(:name_rss_log2)
    log.update_column(:name_id, DANGLING_ID)

    alerts = capture_alerts { CheckOtherRssLogsJob.perform_now }

    assert_not(RssLog.exists?(log.id))
    assert_includes(alerts.first.message, "bogus name_id")
    assert_includes(alerts.first.message, log.id.to_s)
  end

  def test_deletes_ghost_row
    log = rss_logs(:agaricus_campestrus_obs_rss_log)
    log.update_column(:observation_id, nil)

    alerts = capture_alerts { CheckOtherRssLogsJob.perform_now }

    assert_not(RssLog.exists?(log.id))
    assert_equal(1, alerts.size)
    assert_instance_of(JobAlert, alerts.first)
    assert_includes(alerts.first.message, "ghost")
    assert_includes(alerts.first.message, log.id.to_s)
  end

  # A dry-run inspection mutates nothing, so it must stay silent even when
  # there is something to clean up.
  def test_dry_run_does_not_alert
    rss_logs(:agaricus_campestrus_obs_rss_log).update_column(:observation_id,
                                                             nil)

    alerts = capture_alerts do
      CheckOtherRssLogsJob.perform_now(dry_run: true)
    end

    assert_empty(alerts)
  end

  def test_clean_run_does_not_alert
    alerts = capture_alerts { CheckOtherRssLogsJob.perform_now }

    assert_empty(alerts)
  end

  # :observation is CheckObservationRssLogsJob's job -- an orphan
  # observation note must survive a run here (and not alert).
  def test_does_not_check_observation_type
    log = rss_logs(:coprinus_comatus_obs_rss_log)
    log.update_column(:notes, "not a timestamped note\n")

    alerts = capture_alerts { CheckOtherRssLogsJob.perform_now }

    assert_not_nil(log.reload.observation_id)
    assert_empty(alerts)
  end

  def test_perform_runs_end_to_end_without_error
    CheckOtherRssLogsJob.perform_now(verbose: true)
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
