# frozen_string_literal: true

require("test_helper")

module Observations
  class InatResyncsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    tests Observations::InatResyncsController

    # Anyone logged in may trigger a sync.
    def test_any_logged_in_user_enqueues_resync
      obs = reflection
      login("mary") # not the owner, not the observer

      assert_enqueued_with(job: InatObservationResyncJob,
                           args: [obs, users(:mary)]) do
        post(:create, params: { id: obs.id })
      end
      assert_redirected_to(permanent_observation_path(obs.id))
      assert_flash_success
    end

    def test_non_reflection_has_nothing_to_sync
      obs = observations(:imported_inat_obs) # reflected_at nil -> editable
      login(obs.user.login)

      assert_no_enqueued_jobs do
        post(:create, params: { id: obs.id })
      end
      assert_redirected_to(permanent_observation_path(obs.id))
      assert_flash_error
    end

    # Pressing Sync from a non-reflection member of the occurrence works
    # — the job resolves the occurrence's reflections from whichever
    # member it's handed.
    def test_occurrence_member_page_enqueues_for_reflection_sibling
      obs = reflection
      primary = observations(:minimal_unknown_obs)
      [primary, obs].each { |o| o.update_column(:occurrence_id, nil) }
      occ = Occurrence.create!(user: primary.user,
                               primary_observation: primary)
      primary.update!(occurrence: occ)
      obs.update!(occurrence: occ)
      login("mary")

      assert_enqueued_with(job: InatObservationResyncJob,
                           args: [primary, users(:mary)]) do
        post(:create, params: { id: primary.id })
      end
      assert_flash_success
    end

    # The bounce guard debounces on INITIATION, not completion: the
    # second click lands while the first job is still queued — nothing
    # has stamped last_synced_at — and must be swallowed anyway. (The
    # test env cache is a :null_store, so the guard's cache key needs a
    # real store stubbed in; the other tests run guard-free.)
    def test_second_click_while_sync_pending_is_swallowed
      obs = reflection
      login(obs.user.login)

      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        assert_enqueued_jobs(1, only: InatObservationResyncJob) do
          post(:create, params: { id: obs.id })
          post(:create, params: { id: obs.id })
        end
      end
      assert_nil(obs.import_link.reload.last_synced_at,
                 "the guard must not depend on a completed sync")
      assert_flash_success
    end

    # The guard key is the occurrence's reflection set, not the clicked
    # member, so bouncing between member pages debounces together.
    def test_guard_debounces_across_occurrence_member_pages
      obs = reflection
      primary = observations(:minimal_unknown_obs)
      [primary, obs].each { |o| o.update_column(:occurrence_id, nil) }
      occ = Occurrence.create!(user: primary.user,
                               primary_observation: primary)
      primary.update!(occurrence: occ)
      obs.update!(occurrence: occ)
      login("mary")

      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        assert_enqueued_jobs(1, only: InatObservationResyncJob) do
          post(:create, params: { id: obs.id })
          post(:create, params: { id: primary.id })
        end
      end
    end

    def test_guard_expires_and_allows_a_fresh_sync
      obs = reflection
      login(obs.user.login)
      guard = Observations::InatResyncsController::SYNC_GUARD_PERIOD

      Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
        assert_enqueued_jobs(2, only: InatObservationResyncJob) do
          post(:create, params: { id: obs.id })
          travel(guard + 1.second) do
            post(:create, params: { id: obs.id })
          end
        end
      end
    end

    # A full-page redirect would tear down and re-subscribe the
    # Action Cable subscription (#4854) -- under Turbo the response
    # is a flash-only turbo_stream update instead, so the eventual
    # completion broadcast (Inat::ObservationResyncer#broadcast)
    # isn't dropped in that reconnect gap.
    def test_resync_via_turbo_stream_flashes_without_redirect
      obs = reflection
      login(obs.user.login)

      post(:create, params: { id: obs.id }, format: :turbo_stream)

      assert_response(:success)
      assert_select("turbo-stream[action='update'][target='page_flash']")
    end

    private

    def reflection
      obs = observations(:imported_inat_obs)
      obs.update_column(:reflected_at, Time.zone.now)
      obs
    end
  end
end
