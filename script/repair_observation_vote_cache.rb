#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/repair_observation_vote_cache.rb \
#      [-n|--dry-run] [--no-email] [-v|--verbose]
#
#  DESCRIPTION::
#
#    Find + fix + alert for #4171: observations whose `vote_cache`
#    is stuck near 0 even though their consensus-name Naming has a
#    real positive `vote_cache`. The map popup reads `obs.vote_cache`
#    directly, so the stale value shows up there as "0% confidence"
#    even though the obs show page reads correctly.
#
#    Default behavior: find affected obs, repair them by calling
#    `Observation::NamingConsensus#calc_consensus` (which recomputes
#    from the live Naming/Vote rows and saves), and email
#    `MO.webmaster_email_address` with a per-obs detail block of
#    what was just fixed. Safe to re-run; `calc_consensus`'s
#    `update_single_obs_consensus` has an idempotent early-return
#    when nothing actually changed.
#
#    Designed to run in two modes:
#
#    1. **Once on deploy**, with `--no-email`, to clear the
#       historical backlog (1,951 obs on dev DB, mostly 2011-2012).
#       Suppresses the email so we don't ship a giant alert about
#       known historical data.
#    2. **As a daily cronjob**, default flags. Once the backlog is
#       cleared, each run finds 0 or near-0 affected obs and stays
#       silent. When a new occurrence trips it, the obs is auto-fixed
#       *and* an email goes to webmaster with enough detail
#       (timestamps, source, inat_id, user) to investigate the
#       trigger while the trail is fresh (rss_log entries, recent
#       web request logs).
#
#    Exit code: 0 if no affected obs found, 1 if any were repaired
#    (regardless of whether email was sent), 2 on bad usage.
#
#  FLAGS::
#
#    -n / --dry-run  — find only; don't repair, don't email
#    --no-email      — repair, but don't send an email
#                      (use for the deploy-time backlog clear)
#    -v / --verbose  — log each affected obs id with before/after
#
################################################################################

require_relative("../config/boot")
require_relative("../config/environment")

dry_run = false
no_email = false
verbose = false
ARGV.each do |flag|
  case flag
  when "-n", "--dry-run" then dry_run = true
  when "--no-email"      then no_email = true
  when "-v", "--verbose" then verbose = true
  else
    warn("USAGE: bin/rails runner script/repair_observation_vote_cache.rb " \
         "[-n|--dry-run] [--no-email] [-v|--verbose]")
    exit(2)
  end
end
DRY_RUN = dry_run
NO_EMAIL = no_email
VERBOSE = verbose

START = Time.zone.now
EPSILON = 1e-4

def elapsed
  (Time.zone.now - START).round(1)
end

def log(msg)
  puts("[#{elapsed}s] #{msg}")
end

# Find affected obs with everything the email needs in one query.
# Pick a single representative Naming per obs (lowest matching id) so
# duplicates from `(observation_id, name_id)` having no uniqueness
# constraint don't show up multiple times. LEFT JOIN users so we
# don't hit `User.find_by` per row when formatting the alert.
def stale_observations
  sql = <<~SQL.squish
    SELECT obs.id, obs.created_at, obs.updated_at, obs.user_id,
           obs.source, obs.inat_id, n.id, n.vote_cache, u.login
    FROM observations obs
    JOIN namings n ON n.id = (
      SELECT MIN(n2.id) FROM namings n2
      WHERE n2.observation_id = obs.id AND n2.name_id = obs.name_id
    )
    LEFT JOIN users u ON u.id = obs.user_id
    WHERE ABS(IFNULL(obs.vote_cache, 0)) < 0.01
      AND IFNULL(n.vote_cache, 0) > 0.01
    ORDER BY obs.created_at DESC
  SQL
  ActiveRecord::Base.connection.execute(sql).to_a
end

# nil and 0.0 are equivalent for our purposes (both mean "no useful
# vote_cache recorded"); coerce to compare cleanly.
def vote_cache_changed?(before, after)
  (before.to_f - after.to_f).abs > EPSILON
end

# `obs.source` is a Rails enum stored as integer (e.g. 5 →
# `mo_inat_import`). Map back to the symbolic key for human-readable
# diagnostics.
def source_label(source_value)
  return nil if source_value.nil?

  Observation.sources.key(source_value) ||
    Observation.sources.key(source_value.to_i)
end

def format_obs_line(row)
  obs_id, created_at, updated_at, user_id, source, inat_id,
    naming_id, naming_vc, user_login = row
  format("- obs %d: %s\n    " \
         "user %d (%s), created %s, updated %s\n    " \
         "source=%s, inat_id=%s, naming %d vc=%.3f",
         obs_id, Observation.show_url(obs_id),
         user_id, user_login || "?",
         created_at, updated_at,
         source_label(source).inspect, inat_id.inspect,
         naming_id, naming_vc.to_f)
end

def alert_header(count)
  verb = DRY_RUN ? "would be repaired" : "were repaired"
  [
    "vote_cache integrity check found #{count} observation(s) " \
    "whose obs.vote_cache was stale (≈ 0) despite the matching-name " \
    "Naming having a real positive vote_cache. They #{verb}.",
    "",
    "Tracking and root-cause hunt: " \
    "https://github.com/MushroomObserver/mushroom-observer/issues/4171",
    "",
    "Per-obs detail (most recent first, up to 50):",
    ""
  ]
end

def format_alert(rows)
  lines = alert_header(rows.size)
  lines.concat(rows.first(50).map { |r| format_obs_line(r) })
  lines << "" << "(#{rows.size - 50} more not listed)" if rows.size > 50
  lines.join("\n")
end

def recompute_and_classify(obs)
  before = obs.vote_cache
  Observation::NamingConsensus.new(obs).calc_consensus
  obs.reload
  if vote_cache_changed?(before, obs.vote_cache)
    log("  obs #{obs.id} repaired") if VERBOSE
    :repaired
  else
    :unchanged
  end
end

# Returns :repaired / :unchanged / :missing for tally bookkeeping.
def process_obs(obs_id)
  obs = Observation.find_by(id: obs_id)
  return :missing if obs.nil?
  return :repaired if DRY_RUN

  recompute_and_classify(obs)
end

def send_alert(rows)
  WebmasterMailer.build(
    sender_email: MO.webmaster_email_address,
    subject: "[MO] vote_cache integrity check: " \
             "#{rows.size} observation(s) repaired",
    message: format_alert(rows)
  ).deliver_now
end

rows = stale_observations
log("Found #{rows.size} observation(s) with stale vote_cache")
exit(0) if rows.empty?

tally = { repaired: 0, unchanged: 0, missing: 0, errors: 0 }
rows.each_with_index do |row, i|
  log("  #{i}/#{rows.size} processed") if (i % 200).zero? && i.positive?
  tally[process_obs(row[0])] += 1
rescue StandardError => e
  tally[:errors] += 1
  log("  ! obs #{row[0]}: #{e.class}: #{e.message}")
end

verb = DRY_RUN ? "would be repaired" : "repaired"
log("=" * 60)
log("Done: #{tally[:repaired]} #{verb}, " \
    "#{tally[:unchanged]} unchanged, #{tally[:missing]} missing, " \
    "#{tally[:errors]} errors in #{elapsed}s")

if tally[:repaired].positive? && !DRY_RUN && !NO_EMAIL
  send_alert(rows.first(tally[:repaired]))
  log("Sent alert email to #{MO.webmaster_email_address}")
end

exit(1)
