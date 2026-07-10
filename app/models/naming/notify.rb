# frozen_string_literal: true

# Email-notification behavior for Naming: the per-naming notifications sent
# on save, the recipient computation the iNat import digest reuses, and the
# suppression switch bulk creators use to batch instead of flooding. See
# #4757.
#
# create_emails (per-naming send) and notified_user_ids (digest recipients)
# share the same recipient helpers — notification_trackers and
# interested_users — so the two paths can never drift apart.
module Naming::Notify
  extend ActiveSupport::Concern

  class_methods do
    # Bulk creators (the iNat importer) wrap naming creation in this block so
    # create_emails sends nothing per-naming; the caller then sends one
    # digest per interested user instead of thousands of individual emails.
    # Thread-local so concurrent requests/jobs don't affect each other.
    def suppress_notifications
      Thread.current[:naming_suppress_notifications] = true
      yield
    ensure
      Thread.current[:naming_suppress_notifications] = false
    end

    def notifications_suppressed?
      Thread.current[:naming_suppress_notifications] || false
    end
  end

  # Send email notifications after creating or changing the Name.
  def create_emails
    return unless @name_changed

    @name_changed = false
    return if self.class.notifications_suppressed?

    @initial_name_id = name_id
    taxa = notification_taxa
    notify_trackers(taxa)
    notify_interested(taxa)
  end

  # Union of user ids create_emails would notify (name-trackers + interested
  # users, minus the namer). Does not filter no_emails — the digest caller
  # does that once for the whole batch. Lets the import send one digest per
  # user instead of firing per-naming emails.
  def notified_user_ids
    taxa = notification_taxa
    ids = Set.new(notification_trackers(taxa).map(&:user_id))
    ids.merge(interested_users(taxa).map(&:id))
    ids.delete(user_id)
    ids
  end

  private

  # The name plus its ancestor taxa (and Lichen, for lichens) — the chain
  # subscribers are matched along.
  def notification_taxa
    taxa = name.approved_name.all_parents
    taxa.push(name)
    taxa.push(Name.find_by(text_name: "Lichen")) if name.is_lichen?
    taxa
  end

  # NameTrackers to notify along the taxon chain: not the namer, specimen
  # requirement satisfied, deduped to the first tracker seen per user.
  def notification_trackers(taxa)
    seen = Set.new
    taxa.flat_map do |taxon|
      NameTracker.where(name: taxon).includes(:user).select do |tracker|
        tracker.user_id != user_id && seen.add?(tracker.user_id) &&
          (!tracker.require_specimen || observation&.specimen)
      end
    end
  end

  def notify_trackers(taxa)
    notification_trackers(taxa).each do |tracker|
      next if tracker.user.no_emails

      NamingTrackerMailer.build(receiver: tracker.user, naming: self).
        deliver_later
      notify_tracker_observer(tracker)
    end
  end

  # Conditionally notify the observer when the tracker carries a note
  # template (and isn't the observer themselves — no self-email).
  def notify_tracker_observer(tracker)
    return unless tracker.note_template.present? && tracker.approved &&
                  tracker.user != observation.user

    NamingObserverMailer.build(
      receiver: observation.user, naming: self, name_tracker: tracker
    ).deliver_later
  end

  # Users interested in the observation or the name chain: the owner (when
  # they want naming email), positive observation interests, and positive
  # name interests. Negative observation interest removes a user; negative
  # name interest does not (name disinterest shouldn't override obs interest).
  def interested_users(taxa)
    return [] unless (obs = observation)

    users = observation_interest_users(obs)
    taxa.each do |taxon|
      taxon.interests.each { |i| users.push(i.user) if i.state }
    end
    users.uniq
  end

  def observation_interest_users(obs)
    users = []
    users.push(obs.user) if obs.user&.email_observations_naming
    obs.interests.each do |i|
      i.state ? users.push(i.user) : users.delete(i.user)
    end
    users
  end

  def notify_interested(taxa)
    recipients = interested_users(taxa).reject(&:no_emails) - [user]
    recipients.each do |receiver|
      NameProposalMailer.build(
        sender: user, receiver: receiver, naming: self, observation: observation
      ).deliver_later
    end
  end
end
