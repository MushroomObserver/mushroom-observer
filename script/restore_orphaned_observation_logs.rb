# frozen_string_literal: true

# Repair "zombie" observations: live Observations whose RssLog was wrongly
# left in an orphaned state.
#
# Background (GitHub issue #4763): in 2016 a user manually deleted ~850 of
# their observations; the destroys ran normally, orphaning each log (a title
# line prepended above the timestamped history, a `log_observation_destroyed`
# entry added, and every target id nulled). Around 2018 the observations were
# restored from a pre-incident backup -- but the restore never reconciled the
# already-orphaned logs. The result is a live Observation pointing at an
# orphaned log: a landmine that turns into a deletable "ghost" the moment the
# observation is touched. PR #4764 stopped new detonations; this script
# repairs the existing pairs (Option A).
#
# For each zombie it strips the false title line and the bogus
# `log_observation_destroyed` entry from the log's notes, restores
# `rss_logs.observation_id`, and resets `updated_at` to the timestamp of the
# newest surviving (real) entry -- reconstructing the log exactly as it stood
# just before the 2016 destroy. Notes and the foreign key MUST be fixed
# together: re-pointing the FK alone would be re-nulled by
# script/check_rss_logs the next night, because the notes would still lead
# with the title line.
#
# Idempotent: a repaired log has observation_id set, so it drops out of the
# selection on any later run.
#
# Usage (default is a dry run that writes nothing):
#   bin/rails runner script/restore_orphaned_observation_logs.rb
#   bin/rails runner script/restore_orphaned_observation_logs.rb --apply
#   bin/rails runner script/restore_orphaned_observation_logs.rb --apply -v

# Restores live observations whose logs were wrongly left orphaned.
class OrphanedObservationLogRestorer
  DESTROYED = /\A\d{14} log_observation_destroyed(?:\s|\z)/
  TIMESTAMPED = /\A\d{14}/

  def initialize(apply:, verbose:)
    @dry_run = !apply
    @verbose = verbose
    @fixed = 0
    @skipped = []
  end

  def run
    zombies = select_zombies
    @total = zombies.count
    warn("#{"[DRY RUN] " if @dry_run}Found #{@total} zombie observation(s) " \
         "(live observation pointing at an orphaned log).\n\n")
    started = Time.zone.now
    zombies.find_each.with_index do |obs, i|
      process(obs)
      report_progress(i + 1, started)
    end
    report_summary
  end

  private

  def select_zombies
    # find_each batches by primary key ascending, so no explicit order.
    Observation.
      joins("INNER JOIN rss_logs ON rss_logs.id = observations.rss_log_id").
      where(rss_logs: { observation_id: nil })
  end

  def process(obs)
    log = obs.rss_log
    parts = log.notes.to_s.split("\n", 3)
    reason = rejection_reason(parts)
    return skip(obs, log, reason) if reason

    new_time = parse_time(parts[2])
    return skip(obs, log, "bad leading timestamp") if new_time.nil?

    fix(obs, log, parts, new_time)
  end

  # Split gives [title, destroyed_entry, rest]; rest keeps its internal
  # newlines and trailing content byte-for-byte.
  def rejection_reason(parts)
    if parts.size < 3
      "notes have fewer than 3 lines"
    elsif parts[0].match?(TIMESTAMPED)
      "line 1 is timestamped (expected a title line)"
    elsif !parts[1].match?(DESTROYED)
      "line 2 is not a log_observation_destroyed entry"
    elsif !parts[2].match?(TIMESTAMPED)
      "surviving history does not lead with a timestamp"
    end
  end

  def parse_time(rest)
    Time.parse("#{rest[/\A\d{14}/]}+0000")
  rescue ArgumentError
    nil
  end

  def fix(obs, log, parts, new_time)
    old_time = log.updated_at
    unless @dry_run
      log.update_columns(observation_id: obs.id, notes: parts[2],
                         updated_at: new_time)
    end
    @fixed += 1
    return unless @verbose || @dry_run

    warn("FIX  obs #{obs.id} (log #{log.id}) owner=#{obs.user_id} " \
         "updated_at #{old_time.utc.iso8601} -> " \
         "#{new_time.utc.iso8601} | title: #{truncate(parts[0])}")
  end

  def skip(obs, log, reason)
    @skipped << [obs.id, log.id, reason]
    warn("SKIP obs #{obs.id} (log #{log.id}): #{reason}")
  end

  def truncate(str)
    str.length > 60 ? "#{str[0, 57]}..." : str
  end

  def report_progress(done, started)
    return unless (done % 100).zero?

    elapsed = Time.zone.now - started
    rate = elapsed.positive? ? (done / elapsed).round(1) : done
    warn("  ...#{done}/#{@total} processed (#{elapsed.round}s, #{rate}/s)")
  end

  def report_summary
    warn("\n#{@dry_run ? "[DRY RUN] would fix" : "Fixed"} #{@fixed}, " \
         "skipped #{@skipped.size}, of #{@total} found.")
    if @skipped.any?
      warn("Skipped (need manual review):")
      @skipped.each { |oid, lid, why| warn("  obs #{oid} log #{lid}: #{why}") }
    end
    return unless @dry_run && @fixed.positive?

    warn("Re-run with --apply to write the changes.")
  end
end

OrphanedObservationLogRestorer.new(
  apply: ARGV.include?("--apply"),
  verbose: ARGV.include?("--verbose") || ARGV.include?("-v")
).run
