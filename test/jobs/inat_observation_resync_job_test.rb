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

  # The triggering viewer (nil for the future batch job) is what the
  # completion broadcast renders its panel updates from -- confirm the
  # job actually threads it through rather than silently dropping it.
  def test_perform_passes_user_through_to_resyncer
    obs = observations(:imported_inat_obs)
    user = users(:rolf)
    received = nil
    fake_resyncer = Object.new
    def fake_resyncer.resync; end

    Inat::ObservationResyncer.stub(
      :new,
      lambda { |observation, **kwargs|
        received = [observation, kwargs[:user]]
        fake_resyncer
      }
    ) do
      InatObservationResyncJob.perform_now(obs, user)
    end

    assert_equal([obs, user], received)
  end
end
