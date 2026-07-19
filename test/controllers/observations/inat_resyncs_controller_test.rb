# frozen_string_literal: true

require("test_helper")

module Observations
  class InatResyncsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    tests Observations::InatResyncsController

    def test_owner_enqueues_resync
      obs = reflection
      login(obs.user.login)

      assert_enqueued_with(job: InatObservationResyncJob) do
        post(:create, params: { id: obs.id })
      end
      assert_redirected_to(permanent_observation_path(obs.id))
      assert_flash_success
    end

    def test_unrelated_user_is_denied
      obs = reflection
      login("mary") # not the owner, not a collector

      assert_no_enqueued_jobs do
        post(:create, params: { id: obs.id })
      end
      assert_redirected_to(permanent_observation_path(obs.id))
      assert_flash_error
    end

    def test_non_reflection_is_denied
      obs = observations(:imported_inat_obs) # reflected_at nil -> editable
      login(obs.user.login)

      assert_no_enqueued_jobs do
        post(:create, params: { id: obs.id })
      end
      assert_flash_error
    end

    private

    def reflection
      obs = observations(:imported_inat_obs)
      obs.update_column(:reflected_at, Time.zone.now)
      obs
    end
  end
end
