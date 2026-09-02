# frozen_string_literal: true

# User-initiated "Sync now": enqueues a background refresh of
# every read-only reflection in the observation's occurrence from its
# iNaturalist source. The fetch is rate-limited, so the refresh itself
# runs in `InatObservationResyncJob`, not in the request. Any logged-in
# user may trigger a sync.
module Observations
  class InatResyncsController < ApplicationController
    before_action :login_required

    # Debounce for the Sync button, keyed on INITIATION, not completion
    # — a just-clicked sync hasn't stamped anything yet (last_synced_at
    # is written by the job when it finishes), so enqueueing writes a
    # short-lived cache key instead, swallowing re-clicks even while
    # the job is still queued or fetching. Long enough to soak up
    # double-clicks and pile-ons, short enough to be invisible in
    # normal use.
    SYNC_GUARD_PERIOD = 10.seconds

    # POST /observations/:id/resync
    def create
      observation = find_or_goto_index(Observation, params[:id].to_s)
      return unless observation

      reflections = observation.sync_reflections
      if reflections.empty?
        return respond(observation, :observation_resync_nothing, error: true)
      end
      if sync_pending?(reflections)
        return respond(observation, :observation_resync_pending)
      end

      start_sync(observation, reflections)
      respond(observation, :observation_resync_started)
    end

    private

    def sync_pending?(reflections)
      Rails.cache.exist?(guard_key(reflections))
    end

    def start_sync(observation, reflections)
      Rails.cache.write(guard_key(reflections), true,
                        expires_in: SYNC_GUARD_PERIOD)
      # Pass the clicking user so that a placeholder can tell
      # if they are the iNat observer.
      InatObservationResyncJob.perform_later(observation, @user)
    end

    # Keyed on the sorted reflection ids, not the clicked member, so
    # pressing Sync from different member pages of the same occurrence
    # debounces together.
    def guard_key(reflections)
      "inat_resync_guard/#{reflections.map(&:id).sort.join("-")}"
    end

    # A full-page redirect would tear down and re-subscribe the
    # turbo_stream_from([observation, :external_link_sync]) Action
    # Cable subscription on the show page -- if the resync job's async
    # broadcast fires during that reconnect gap, the broadcast is
    # dropped with no replay (#4854, same race Images::
    # TransformationsController#update works around the same way).
    # Responding with a flash-only turbo_stream instead keeps the
    # existing subscription alive. Non-Turbo requests still redirect.
    def respond(observation, tag, error: false)
      error ? flash_error(tag.t) : flash_notice(tag.t)
      respond_to do |format|
        format.turbo_stream { render(turbo_stream: turbo_stream_flash_update) }
        format.html do
          redirect_to(permanent_observation_path(observation.id))
        end
      end
    end
  end
end
