# frozen_string_literal: true

# Solid Cable silences its recurring polling queries (Listener#listen
# wraps them in #with_polling_volume, which uses
# ActiveRecord::Base.logger.silence), but NOT the one-off
# `SELECT MAX(id) FROM solid_cable_messages` that Listener#add_channel
# runs for every new stream subscription. Since #4825 subscribes every
# rendered image to a [image, :processed] stream, a single page load
# emits dozens of those lines into the development log. Wrap
# #add_channel in the same silencer the gem already uses for polling.
#
# Gem-version-specific (solid_cable 3.0.12) -- remove if a future
# solid_cable release silences #add_channel itself.
require("action_cable/subscription_adapter/solid_cable")

module SolidCableSubscribeSilencer
  def add_channel(...)
    with_polling_volume { super }
  end
end

ActionCable::SubscriptionAdapter::SolidCable::Listener.prepend(
  SolidCableSubscribeSilencer
)
