# frozen_string_literal: true

# Cleans up `rss_logs` rows that have fallen out of sync with their
# target. An RssLog's `notes` column starts with a 14-digit timestamp
# (`YYYYMMDDHHMMSS...`) once it's a "real" structured log entry for some
# target row; anything else (free-form text, usually from before the
# structured format existed) is an "orphan" note.
#
# For each type this job is given (see #check_types):
#   - orphan notes with a type_id still set: the type_id shouldn't be
#     there on an orphan note, so null it out.
#   - real (timestamped) notes whose type_id points at a deleted row:
#     the whole log is meaningless without its target, so delete it.
#     (CheckForBrokenReferencesJob independently catches the same
#     dangling-reference case for RssLog on a weekly cadence; this job
#     runs daily, so it's kept here too rather than removed as
#     redundant - catching it same-day beats waiting up to a week.)
# The subclass covering the rest of RssLog::ALL_TYPE_TAGS also deletes
# "ghost" rows: real (timestamped) notes with every type_id column nil,
# i.e. claiming to be a structured entry for no target at all.
#
# Abstract base, never scheduled directly (see config/recurring.yml) --
# CheckObservationRssLogsJob and CheckOtherRssLogsJob are the two
# concrete subclasses. Split by measured cost: `observation` alone was
# ~46% of this job's total runtime (its reference table, `observations`,
# dwarfs every other type's -- 605K rows locally vs. 70K for the next
# largest, `names`), so it gets its own schedule slot instead of every
# other (much cheaper) type queuing behind it.
class CheckRssLogsJob < ApplicationJob
  queue_as :maintenance

  TIMESTAMPED_NOTES = "^[0-9]{14}"

  def perform(dry_run: false, verbose: false)
    @dry_run = dry_run
    @verbose = verbose

    check_types.each { |type| check_type(type) }
    delete_ghosts if check_ghosts?
  end

  private

  # Subclasses must implement: which RssLog::ALL_TYPE_TAGS this job
  # instance checks.
  def check_types
    raise(NotImplementedError.new("Subclasses must implement check_types"))
  end

  # Only one subclass needs to run this -- ghosts aren't specific to
  # any one type, so there's no reason to run this check twice.
  def check_ghosts?
    false
  end

  def check_type(type)
    log("checking #{type}...") if @verbose
    null_orphans_with_type(type)
    delete_nonorphans_with_bogus_type(type)
  end

  def null_orphans_with_type(type)
    column = :"#{type}_id"
    query = RssLog.where.not(column => nil).where(non_timestamped_notes)
    ids = timed("null_orphans_with_type(#{type})") { query.pluck(:id) }
    return if ids.empty?

    query.update_all(column => nil) unless @dry_run
    log("NULLING #{column} on #{ids.size} orphan rss_log(s)#{log_suffix(ids)}")
  end

  def delete_nonorphans_with_bogus_type(type)
    column = :"#{type}_id"
    query = bogus_type_query(type, column)
    ids = timed("delete_nonorphans_with_bogus_type(#{type})") do
      query.pluck(:id)
    end
    return if ids.empty?

    query.delete_all unless @dry_run
    log("DELETING #{ids.size} rss_log(s) with bogus #{column}" \
        "#{log_suffix(ids)}")
  end

  def bogus_type_query(type, column)
    ref_model = type.to_s.classify.constantize
    RssLog.where.not(column => nil).where(timestamped_notes).
      where.not(column => ref_model.all)
  end

  def delete_ghosts
    query = RssLog.where(timestamped_notes).where(all_type_ids_nil)
    ids = timed("delete_ghosts") { query.pluck(:id) }
    return if ids.empty?

    query.delete_all unless @dry_run
    log("DELETING #{ids.size} ghost rss_log(s)#{log_suffix(ids)}")
  end

  # Always logs elapsed time for the query's pluck(:id) (where the full
  # table scan on rss_logs.notes REGEXP actually happens) -- not gated
  # behind @verbose, unlike the id-list dumps below. Added to find which
  # of this job's 15 near-identical per-type/ghost queries dominates a
  # slow production run, instead of guessing.
  def timed(label)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    log(format("%s: %.2fs", label, elapsed))
    result
  end

  # Bounded id sample (only when verbose) plus a "(dry run)" marker so
  # a dry run's log line doesn't read as if it actually mutated data.
  def log_suffix(ids)
    "#{ids_suffix(ids)}#{dry_run_note}"
  end

  def dry_run_note
    @dry_run ? " (dry run)" : ""
  end

  def ids_suffix(ids)
    @verbose ? " #{ids.inspect}" : ""
  end

  def all_type_ids_nil
    RssLog::ALL_TYPE_TAGS.to_h { |type| [:"#{type}_id", nil] }
  end

  def timestamped_notes
    RssLog.arel_table[:notes].matches_regexp(TIMESTAMPED_NOTES)
  end

  def non_timestamped_notes
    RssLog.arel_table[:notes].does_not_match_regexp(TIMESTAMPED_NOTES)
  end
end
