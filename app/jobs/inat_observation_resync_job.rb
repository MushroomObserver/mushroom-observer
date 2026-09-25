# frozen_string_literal: true

# Refreshes every read-only reflection in an observation's occurrence
# from its iNaturalist source (#4215). Runs in the background because the
# resync makes a rate-limited iNat API call; the user-initiated "Sync
# now" button and (later) the scheduled batch both enqueue this. Sync is
# owned by the admin account -- see Inat::ObservationResyncer#log_resync
# -- so no triggering user is carried.
class InatObservationResyncJob < ApplicationJob
  queue_as :default

  def perform(observation)
    resyncer = Inat::ObservationResyncer.new(observation)
    resyncer.resync
    # Same treatment as the scheduled batch gives them
    # (InatReflectionBatchResyncJob): a sync engine that declined to act
    # is for a human to look at, and nothing else surfaces these.
    resyncer.alerts.each { |message| alert(message) }
  end
end
