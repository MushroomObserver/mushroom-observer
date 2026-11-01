# frozen_string_literal: true

# Refreshes every read-only reflection in an observation's occurrence
# from its iNaturalist source (#4215). Runs in the background because the
# resync makes a rate-limited iNat API call; the user-initiated "Sync
# now" button and (later) the scheduled batch both enqueue this. Sync is
# owned by the admin account -- see Inat::ReflectionResync#log_resync.
# The triggering user is carried only to decide whether a placeholder
# reflection is upgraded (see Inat::ReflectionResync#initialize).
class InatObservationResyncJob < ApplicationJob
  queue_as :default

  def perform(observation, requested_by = nil)
    resyncer = Inat::ObservationResyncer.new(observation,
                                             requested_by: requested_by)
    resyncer.resync
    # Same treatment as the scheduled batch gives them
    # (InatReflectionBatchResyncJob): a sync engine that declined to act
    # is for a human to look at, and nothing else surfaces these.
    resyncer.alerts.each { |message| alert(message) }
  end
end
