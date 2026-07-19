# frozen_string_literal: true

# Refreshes one read-only reflection observation from its iNaturalist
# source (#4215). Runs in the background because the resync makes a
# rate-limited iNat API call; the user-initiated "Sync now" button and
# (later) the daily batch both enqueue this.
class InatObservationResyncJob < ApplicationJob
  queue_as :default

  def perform(observation)
    Inat::ObservationResyncer.new(observation).resync
  end
end
