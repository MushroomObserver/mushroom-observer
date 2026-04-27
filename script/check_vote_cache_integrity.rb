#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/check_vote_cache_integrity.rb \
#      [-q|--quiet] [-n|--no-email]
#
#  DESCRIPTION::
#
#    Cron-friendly integrity check for #4171. Finds observations whose
#    `vote_cache` is stuck near 0 even though their consensus-name
#    Naming has a real positive `vote_cache` — the same pattern fixed
#    by `script/repair_observation_vote_cache.rb`.
#
#    Sends an email to `MO.webmaster_email_address` when any are
#    found, with a per-obs detail block so the trigger can be traced
#    while the trail is fresh (rss_log entries, recent web request
#    logs). Exits 0 if everything's consistent (no email sent),
#    1 otherwise.
#
#    Run nightly as its own cronjob — separate from
#    `script/refresh_caches`, which doesn't notify on surprises.
#    Once the historical backlog has been cleared by
#    `script/repair_observation_vote_cache.rb`, any non-zero
#    finding here is a new occurrence and worth investigating.
#
#  FLAGS::
#
#    -q / --quiet    — suppress stdout (email still sends)
#    -n / --no-email — print to stdout only; don't send email
#                      (useful for ad-hoc local checks)
#
################################################################################

require_relative("../config/boot")
require_relative("../config/environment")

quiet = false
no_email = false
ARGV.each do |flag|
  case flag
  when "-q", "--quiet"    then quiet = true
  when "-n", "--no-email" then no_email = true
  else
    warn("USAGE: bin/rails runner script/check_vote_cache_integrity.rb " \
         "[-q|--quiet] [-n|--no-email]")
    exit(2)
  end
end
QUIET = quiet
NO_EMAIL = no_email

def stale_observations
  # Pick one representative Naming per obs (the lowest-id matching one)
  # so an obs with multiple Namings at its consensus name doesn't show
  # up multiple times in the alert. Also LEFT JOIN users so we don't
  # do a `User.find_by` per row when formatting (the alert can list up
  # to 50 obs).
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

# `obs.source` is a Rails enum stored as integer (e.g. 5 for
# `mo_inat_import`). The raw SQL select returns the integer; map
# back to the symbolic key for human-readable diagnostics.
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
  [
    "vote_cache integrity check found #{count} observation(s) " \
    "whose obs.vote_cache is stale (≈ 0) despite the matching-name " \
    "Naming having a real positive vote_cache.",
    "",
    "Run script/repair_observation_vote_cache.rb to fix; tracking " \
    "and root-cause hunt at " \
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

rows = stale_observations
if rows.empty?
  puts("vote_cache integrity OK: no stale observations.") unless QUIET
  exit(0)
end

message = format_alert(rows)
puts(message) unless QUIET

unless NO_EMAIL
  WebmasterMailer.build(
    sender_email: MO.webmaster_email_address,
    subject: "[MO] vote_cache integrity check: " \
             "#{rows.size} stale observation(s)",
    message: message
  ).deliver_now
end

exit(1)
