# frozen_string_literal: true

# User-initiated "Sync now" for a read-only reflection observation
# (#4215): enqueues a background resync of the observation from its
# iNaturalist source. The fetch is rate-limited, so the actual refresh
# runs in `InatObservationResyncJob`, not in the request.
module Observations
  class InatResyncsController < ApplicationController
    before_action :login_required

    # POST /observations/:id/resync
    def create
      observation = find_or_goto_index(Observation, params[:id].to_s)
      return unless observation
      unless can_resync?(observation)
        return respond(observation, :observation_resync_denied, error: true)
      end

      InatObservationResyncJob.perform_later(observation, @user)
      respond(observation, :observation_resync_started)
    end

    private

    def can_resync?(observation)
      observation.resyncable_by?(@user) ||
        (observation.reflection? && in_admin_mode?)
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
