# frozen_string_literal: true

# Refreshes one read-only reflection observation from its iNaturalist
# source (#4215). Runs in the background because the resync makes a
# rate-limited iNat API call; the user-initiated "Sync now" button and
# (later) the daily batch both enqueue this.
#
# `user:` is the viewer who triggered the resync (nil for the future
# batch job, which has no single triggering viewer) -- the completion
# broadcast renders its panel updates from that viewer's permissions
# (e.g. which external sites they may still add a link to), so a
# broadcast without a user renders the safe, logged-out-equivalent view.
class InatObservationResyncJob < ApplicationJob
  queue_as :default

  def perform(observation, user = nil)
    Inat::ObservationResyncer.new(observation, user: user).resync
  end
end
