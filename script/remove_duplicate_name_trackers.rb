# frozen_string_literal: true

# One-time repair (#5458), and the precondition for the unique index on
# `name_trackers (user_id, name_id)`.
#
# `Names::TrackersController#create` did not look for an existing
# tracker, so each resubmit of the new-tracker form added another one.
# With duplicates, Disable removes one and the user keeps getting email
# from the rest. `create` updates the existing tracker now, so no new
# duplicates arise. This removes the ones already here: per user and
# Name it keeps one tracker and destroys the others with their
# Interests.
#
# Dry run (default -- reports, writes nothing):
#   bin/rails runner script/remove_duplicate_name_trackers.rb
# Apply:
#   bin/rails runner script/remove_duplicate_name_trackers.rb --apply

# Removes all but one NameTracker per user and Name.
class DuplicateNameTrackerRemoval
  COMMAND = "bin/rails runner script/remove_duplicate_name_trackers.rb"

  def initialize(apply:)
    @apply = apply
    @counts = Hash.new(0)
  end

  def run
    groups = duplicate_groups
    warn("#{groups.size} user/Name pairs with more than one tracker")
    groups.each { |user_id, name_id| repair(user_id, name_id) }
    report
  end

  # A tracker with a note template carries the user's message to
  # observers, so it outranks one without; an approved template outranks
  # an unapproved one. Otherwise the oldest survives.
  def self.keeper(trackers)
    trackers.min_by do |tracker|
      [tracker.note_template.present? ? 0 : 1, tracker.approved ? 0 : 1,
       tracker.id]
    end
  end

  private

  def duplicate_groups
    NameTracker.group(:user_id, :name_id).
      having(NameTracker.arel_table[:id].count.gt(1)).count.keys
  end

  def repair(user_id, name_id)
    trackers = NameTracker.where(user_id:, name_id:).to_a
    keep = self.class.keeper(trackers)
    extras = trackers - [keep]
    log_pair(user_id, name_id, keep, extras)
    @counts[:pairs] += 1
    return @counts[:trackers_would_remove] += extras.size unless @apply

    extras.each(&:destroy)
    @counts[:trackers_removed] += extras.size
  end

  def log_pair(user_id, name_id, keep, extras)
    warn("  User #{user_id}, Name #{name_id}: keep #{describe(keep)}; " \
         "remove #{extras.map { describe(it) }.join(", ")}")
  end

  def describe(tracker)
    flags = []
    flags << "note" if tracker.note_template.present?
    flags << "approved" if tracker.approved
    flags << "specimen" if tracker.require_specimen
    "#{tracker.id}#{" (#{flags.join(", ")})" if flags.any?}"
  end

  def report
    if @counts.any?
      warn(@counts.map { |key, count| "#{key}: #{count}" }.join(", "))
    end
    return if @apply

    warn("Dry run - nothing written. To apply: #{COMMAND} --apply")
  end
end

if $PROGRAM_NAME == __FILE__
  apply = ARGV.delete("--apply") ? true : false
  if ARGV.any?
    warn("Unknown argument(s): #{ARGV.join(", ")}")
    warn("Usage: #{DuplicateNameTrackerRemoval::COMMAND} [--apply]")
    exit(1)
  end
  DuplicateNameTrackerRemoval.new(apply:).run
end
