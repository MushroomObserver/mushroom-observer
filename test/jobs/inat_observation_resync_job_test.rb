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

  # Every resync is still logged as the admin account;
  # the scheduled batch has no triggering user, so
  # the job defaults to nil when none is given.
  def test_perform_hands_resyncer_the_observation_with_no_user_by_default
    obs = observations(:imported_inat_obs)
    received = nil

    Inat::ObservationResyncer.stub(
      :new,
      lambda { |observation, **kwargs|
        received = [observation, kwargs]
        fake_resyncer
      }
    ) do
      InatObservationResyncJob.perform_now(obs)
    end

    assert_equal([obs, { user: nil }], received,
                 "the job user should be nil if no user is given")
  end

  def test_perform_hands_resyncer_the_syncing_user_when_given
    obs = observations(:imported_inat_obs)
    received = nil
    syncing_user = users(:mary)

    Inat::ObservationResyncer.stub(
      :new,
      lambda { |observation, **kwargs|
        received = [observation, kwargs]
        fake_resyncer
      }
    ) do
      InatObservationResyncJob.perform_now(obs, syncing_user)
    end

    assert_equal(
      [obs, { user: syncing_user }], received,
      "the job user should be the syncing user for a user-initiated sync"
    )
  end

  private

  def fake_resyncer
    resyncer = Object.new
    def resyncer.resync; end
    resyncer
  end
end
