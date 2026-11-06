# frozen_string_literal: true

# Shared recipient-collection helpers for a model's `notify_users`-style
# callback, which emails admins/authors/editors/etc. plus Interest
# watchers about a change. Included by Location, LocationDescription,
# Name, NameDescription, and Observation.
module Interested
  # Pushes each user from every `[users, pref]` pair onto `recipients`
  # if that user has opted into `pref`. `users` may be a single User
  # (or nil), a flat list (e.g. `authors`), or a list of lists (e.g.
  # `descriptions.map(&:authors)`, aggregating a role across every
  # description of a Location/Name) -- `Array(...).flatten.compact`
  # normalizes all three shapes the same way.
  def collect_role_recipients(role_pairs, recipients)
    role_pairs.each do |users, pref|
      Array(users).flatten.compact.each do |user|
        recipients.push(user) if user.public_send(pref)
      end
    end
  end

  # Drops opted-out users, then de-dupes and removes `sender`. Call
  # this last, right before the mailer-dispatch loop.
  def finalize_recipients!(recipients, sender)
    recipients.reject!(&:no_emails)
    recipients.uniq - [sender]
  end
end
