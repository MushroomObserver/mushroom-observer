# frozen_string_literal: true

# Cleans up `rss_logs` rows that have fallen out of sync with their
# target. An RssLog's `notes` column starts with a 14-digit timestamp
# (`YYYYMMDDHHMMSS...`) once it's a "real" structured log entry for some
# target row; anything else (free-form text, usually from before the
# structured format existed) is an "orphan" note.
#
# For each of RssLog::ALL_TYPE_TAGS:
#   - orphan notes with a type_id still set: the type_id shouldn't be
#     there on an orphan note, so null it out.
#   - real (timestamped) notes whose type_id points at a deleted row:
#     the whole log is meaningless without its target, so delete it.
#     (CheckForBrokenReferencesJob independently catches the same
#     dangling-reference case for RssLog on a weekly cadence; this job
#     runs daily, so it's kept here too rather than removed as
#     redundant - catching it same-day beats waiting up to a week.)
# Finally, deletes "ghost" rows: real (timestamped) notes with every
# type_id column nil, i.e. claiming to be a structured entry for no
# target at all.
class CheckRssLogsJob < ApplicationJob
  queue_as :maintenance

  TIMESTAMPED_NOTES = "^[0-9]{14}"

  def perform(dry_run: false, verbose: false)
    @dry_run = dry_run
    @verbose = verbose

    RssLog::ALL_TYPE_TAGS.each { |type| check_type(type) }
    delete_ghosts
  end

  private

  def check_type(type)
    log("checking #{type}...") if @verbose
    null_orphans_with_type(type)
    delete_nonorphans_with_bogus_type(type)
  end

  def null_orphans_with_type(type)
    column = :"#{type}_id"
    query = RssLog.where.not(column => nil).where(non_timestamped_notes)
    ids = query.pluck(:id)
    return if ids.empty?

    query.update_all(column => nil) unless @dry_run
    log("NULLING #{column} on #{ids.size} orphan rss_log(s)#{log_suffix(ids)}")
  end

  def delete_nonorphans_with_bogus_type(type)
    column = :"#{type}_id"
    ref_model = type.to_s.classify.constantize
    query = RssLog.where.not(column => nil).where(timestamped_notes).
            where.not(column => ref_model.all)
    ids = query.pluck(:id)
    return if ids.empty?

    query.delete_all unless @dry_run
    log("DELETING #{ids.size} rss_log(s) with bogus #{column}" \
        "#{log_suffix(ids)}")
  end

  def delete_ghosts
    query = RssLog.where(timestamped_notes).where(all_type_ids_nil)
    ids = query.pluck(:id)
    return if ids.empty?

    query.delete_all unless @dry_run
    log("DELETING #{ids.size} ghost rss_log(s)#{log_suffix(ids)}")
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
