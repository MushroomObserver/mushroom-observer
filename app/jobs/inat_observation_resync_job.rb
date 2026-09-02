# frozen_string_literal: true

# Refresh every read-only reflection in an observation's occurrence
# from its iNatt source.
# Runs in the background because the
# resync makes a rate-limited iNat API call; the user-initiated "Sync
# now" button and (later) the scheduled batch both enqueue this.
# Includes `user` to see if a placeholder can be upgraded to a full import.
# Resync is logged as the admin account regardless of `user`.
class InatObservationResyncJob < ApplicationJob
  queue_as :default

  def perform(observation, user = nil)
    Inat::ObservationResyncer.new(observation, user: user).resync
  end
end
