# frozen_string_literal: true

# User-initiated "Sync now" (#4215): enqueues a background refresh of
# every read-only reflection in the observation's occurrence from its
# iNaturalist source. The fetch is rate-limited, so the actual refresh
# runs in `InatObservationResyncJob`, not in the request. Any logged-in
# user may trigger a sync — it applies no user input, converging on
# source-canonical data, the same refresh the scheduled batch performs.
module Observations
  class InatResyncsController < ApplicationController
    before_action :login_required

    # Clicks while every reflection was synced this recently skip the
    # fetch entirely — long enough to swallow double-clicks and
    # pile-ons, short enough to be invisible in normal use.
    SYNC_GUARD_PERIOD = 10.seconds

    # POST /observations/:id/resync
    def create
      observation = find_or_goto_index(Observation, params[:id].to_s)
      return unless observation

      reflections = observation.sync_reflections
      if reflections.empty?
        return respond(observation, :observation_resync_nothing, error: true)
      end
      return respond(observation, :observation_resync_recent) if
        recently_synced?(reflections)

      InatObservationResyncJob.perform_later(observation)
      respond(observation, :observation_resync_started)
    end

    private

    def recently_synced?(reflections)
      links = reflections.filter_map(&:import_link)
      links.any? &&
        links.all? { |l| l.last_synced_at&.after?(SYNC_GUARD_PERIOD.ago) }
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
