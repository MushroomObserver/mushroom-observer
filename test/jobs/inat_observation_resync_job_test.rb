# frozen_string_literal: true

require("test_helper")

class InatObservationResyncJobTest < ActiveJob::TestCase
  # Stands in for Inat::ObservationResyncer, carrying whatever engine
  # alerts a test wants the job to find. One class rather than a
  # per-test singleton: LocalizationFilesTest scans source files for
  # repeated method definitions and counts `def fake.resync` in two
  # tests as a duplicate.
  FakeResyncer = Struct.new(:alerts) do
    def resync; end
  end

  # The job is a thin wrapper around Inat::ObservationResyncer. A
  # non-reflection observation exercises the wiring without any network
  # call, because the resyncer's guard returns before it fetches.
  def test_perform_delegates_to_resyncer
    obs = observations(:imported_inat_obs) # reflected_at nil -> not synced
    link = obs.import_link

    assert_nothing_raised do
      InatObservationResyncJob.perform_now(obs)
    end
    assert_nil(link.reload.last_synced_at,
               "a non-reflection is left untouched (guard, no fetch)")
  end

  # Sync is owned by the admin account (#4215) -- the job carries no
  # user, so it hands the resyncer just the observation.
  def test_perform_hands_resyncer_the_observation_only
    obs = observations(:imported_inat_obs)
    received = nil
    fake_resyncer = FakeResyncer.new([])

    Inat::ObservationResyncer.stub(
      :new,
      lambda { |observation, **kwargs|
        received = [observation, kwargs]
        fake_resyncer
      }
    ) do
      InatObservationResyncJob.perform_now(obs)
    end

    assert_equal([obs, {}], received)
  end

  # A sync engine that declined to act had nowhere to report it on the
  # "Sync now" path: the resyncer collected the messages and no one read
  # them. They get the same #alerts treatment the scheduled batch gives
  # them (InatReflectionBatchResyncJob).
  def test_perform_forwards_engine_alerts
    obs = observations(:imported_inat_obs)
    fake_resyncer = FakeResyncer.new(["obs 5: photo not imported"])

    sent = []
    Inat::ObservationResyncer.stub(:new, ->(*, **) { fake_resyncer }) do
      ExceptionNotifier.stub(:notifiers, [:slack]) do
        ExceptionNotifier.stub(
          :notify_exception,
          ->(exception, **_opts) { sent << exception.message }
        ) { InatObservationResyncJob.perform_now(obs) }
      end
    end

    assert_equal(["obs 5: photo not imported"], sent)
  end
end
