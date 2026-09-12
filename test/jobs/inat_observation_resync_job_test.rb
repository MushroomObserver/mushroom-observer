# frozen_string_literal: true

require("test_helper")

class InatObservationResyncJobTest < ActiveJob::TestCase
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
    fake_resyncer = Object.new
    def fake_resyncer.resync; end

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
end
