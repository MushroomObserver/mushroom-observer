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
      return redirect_denied(observation) unless can_resync?(observation)

      InatObservationResyncJob.perform_later(observation)
      flash_notice(:observation_resync_started.t)
      redirect_to(permanent_observation_path(observation.id))
    end

    private

    def can_resync?(observation)
      observation.resyncable_by?(@user) ||
        (observation.reflection? && in_admin_mode?)
    end

    def redirect_denied(observation)
      flash_error(:observation_resync_denied.t)
      redirect_to(permanent_observation_path(observation.id))
    end
  end
end
