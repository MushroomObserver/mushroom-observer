# frozen_string_literal: true

require("test_helper")

module Observations
  class InatResyncsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    tests Observations::InatResyncsController

    # Anyone logged in may trigger a sync (#4215) — it applies no user
    # input, converging on source-canonical data — and the job carries
    # no user (sync is owned by the admin account).
    def test_any_logged_in_user_enqueues_resync
      obs = reflection
      login("mary") # not the owner, not a collector

      assert_enqueued_with(job: InatObservationResyncJob, args: [obs]) do
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

      assert_enqueued_with(job: InatObservationResyncJob, args: [primary]) do
        post(:create, params: { id: primary.id })
      end
      assert_flash_success
    end

    # The spam guard: when every reflection in the occurrence was synced
    # within the last SYNC_GUARD_PERIOD, the click reports "just synced"
    # and skips the fetch entirely.
    def test_recently_synced_occurrence_skips_the_fetch
      obs = reflection
      obs.import_link.update!(last_synced_at: 2.seconds.ago)
      login(obs.user.login)

      assert_no_enqueued_jobs do
        post(:create, params: { id: obs.id })
      end
      assert_redirected_to(permanent_observation_path(obs.id))
      assert_flash_success
    end

    def test_stale_last_synced_at_does_not_block_a_resync
      obs = reflection
      obs.import_link.update!(last_synced_at: 1.minute.ago)
      login(obs.user.login)

      assert_enqueued_with(job: InatObservationResyncJob) do
        post(:create, params: { id: obs.id })
      end
      assert_flash_success
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
