# frozen_string_literal: true

# Restore the deleted RssLogs of "detonated" observations, from notes
# recovered out of older database backups (GitHub issue #4763).
#
# When one of bloodworm's zombie observations (see
# restore_orphaned_observation_logs.rb) was touched before PR #4764 landed,
# its orphaned log turned into a "ghost" and script/check_rss_logs deleted
# it, leaving the live observation with a dangling (or NULL) rss_log_id and
# no history. This script recreates those logs where the pre-deletion notes
# could still be recovered from a backup, re-links the observation, and sets
# updated_at to the newest surviving entry so the log reads as it did before.
#
# The recovered notes below were extracted from the 2024-01-01 backup (which
# still held these three logs in their orphaned state) and cleaned the same
# way restore_orphaned_observation_logs.rb cleans a zombie: the false title
# line and the log_observation_destroyed entry were dropped, leaving the real
# pre-2016 history.
#
# NOT recovered (their logs were already gone from the oldest backup we have,
# 2024-01-01, so their history is lost unless an earlier dump turns up):
#   obs 205554 (log 233520, detonated 2022-04-23)
#   obs 140593 (log 159708, detonated 2022-09-19; obs since got a fresh log)
#   obs 131983 (log 149611, detonated 2022-10-02)
#   obs  96712 (log 105921, detonated 2023-07-22)
# A single backup from before 2022-04-23 would hold all four.
#
# Usage (dry run by default; --apply to write):
#   bin/rails runner script/restore_deleted_observation_logs.rb
#   bin/rails runner script/restore_deleted_observation_logs.rb --apply

# Recreates deleted observation logs from backup-recovered notes.
class DeletedObservationLogRestorer
  RECORDS = [
    # obs 159258 -- Phellinus gilvus
    {
      log_id: 182_192, obs_id: 159_258,
      created_at: "2014-02-06 21:50:32", updated_at: "2014-02-06 21:50:41",
      notes: <<~NOTES.chomp
        20140206215041 log_observation_created_at user bloodworm
        20140206215041 log_image_created_at name Image%20#402504 user bloodworm
        20140206215040 log_consensus_changed new **__Phellinus%20gilvus__**%20(Schwein.)%20Pat. old **__Fungi__** user bloodworm
      NOTES
    },
    # obs 218032 -- Chromosera cyanophylla
    {
      log_id: 247_617, obs_id: 218_032,
      created_at: "2015-10-07 21:59:02", updated_at: "2015-10-07 21:59:11",
      notes: <<~NOTES.chomp
        20151007215911 log_observation_created_at user inspiteofourselves
        20151007215911 log_image_created_at name Image%20#562015 user inspiteofourselves
        20151007215909 log_image_created_at name Image%20#562014 user inspiteofourselves
        20151007215908 log_consensus_changed new **__Chromosera%20cyanophylla__**%20(Fr.)%20Redhead,%20Ammirati%20&%20Norvell old **__Fungi__**%20Bartl. user inspiteofourselves
      NOTES
    },
    # obs 223025 -- Hericium erinaceus
    {
      log_id: 253_226, obs_id: 223_025,
      created_at: "2015-11-15 07:16:18", updated_at: "2015-11-15 07:16:23",
      notes: <<~NOTES.chomp
        20151115071623 log_observation_created_at user inspiteofourselves
        20151115071623 log_image_created_at name Image%20#575862 user inspiteofourselves
        20151115071621 log_consensus_changed new **__Hericium%20erinaceus__**%20(Bull.)%20Pers. old **__Fungi__**%20Bartl. user inspiteofourselves
      NOTES
    }
  ].freeze

  def initialize(apply:)
    @dry_run = !apply
    @done = 0
    @skipped = []
  end

  def run
    warn("#{"[DRY RUN] " if @dry_run}Restoring #{RECORDS.size} deleted " \
         "observation log(s).\n\n")
    RECORDS.each { |rec| process(rec) }
    report
  end

  private

  def process(rec)
    obs = Observation.find_by(id: rec[:obs_id])
    return skip(rec, "observation not found") unless obs
    return skip(rec, "log already exists") if RssLog.exists?(rec[:log_id])

    restore(obs, rec) unless @dry_run
    @done += 1
    warn("#{@dry_run ? "WOULD RESTORE" : "RESTORED"} log #{rec[:log_id]} " \
         "-> obs #{rec[:obs_id]} (updated_at #{rec[:updated_at]})")
  end

  # insert! writes the row directly -- no callbacks, no timestamp override --
  # so the recovered created_at / updated_at are preserved verbatim.
  def restore(obs, rec)
    RssLog.insert!(rec.slice(:created_at, :updated_at, :notes).
                   merge(id: rec[:log_id], observation_id: rec[:obs_id]))
    obs.update_column(:rss_log_id, rec[:log_id])
  end

  def skip(rec, reason)
    @skipped << [rec[:obs_id], rec[:log_id], reason]
    warn("SKIP obs #{rec[:obs_id]} log #{rec[:log_id]}: #{reason}")
  end

  def report
    warn("\n#{@dry_run ? "[DRY RUN] would restore" : "Restored"} #{@done}, " \
         "skipped #{@skipped.size}, of #{RECORDS.size}.")
    return unless @dry_run && @done.positive?

    warn("Re-run with --apply to write the changes.")
  end
end

DeletedObservationLogRestorer.new(apply: ARGV.include?("--apply")).run
