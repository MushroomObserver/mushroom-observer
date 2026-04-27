#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/repair_observation_vote_cache.rb \
#      [-n|--dry-run] [-v|--verbose]
#
#  DESCRIPTION::
#
#    One-shot repair for #4171: ~1,951 historical observations have a
#    stale `vote_cache` that says 0% even though their consensus name's
#    Naming has a real positive `vote_cache`. The data is fine; only
#    the obs cache wasn't refreshed at the time of an old edit (mostly
#    2011-2012, on a handful of users). The map popup uses
#    `obs.vote_cache` directly, so the stale value shows up there as
#    "0% confidence" even though the obs show page reads correctly.
#
#    Strategy: walk the affected obs and call
#    `Observation::NamingConsensus#calc_consensus` on each.
#    `calc_consensus` recomputes from the live Naming/Vote rows and
#    saves via `update_single_obs_consensus`, with an idempotent early
#    return when nothing actually changed. Safe to re-run.
#
#    Use --dry-run to count without saving (still constructs the
#    consensus calculator per obs so you can see runtime). Use
#    --verbose to list each affected obs id.
#
################################################################################

require_relative("../config/boot")
require_relative("../config/environment")

dry_run = false
verbose = false
ARGV.each do |flag|
  case flag
  when "-n", "--dry-run" then dry_run = true
  when "-v", "--verbose" then verbose = true
  else
    puts("USAGE: bin/rails runner script/repair_observation_vote_cache.rb " \
         "[-n|--dry-run] [-v|--verbose]")
    exit(1)
  end
end
DRY_RUN = dry_run
VERBOSE = verbose

START = Time.zone.now

def elapsed
  (Time.zone.now - START).round(1)
end

def log(msg)
  puts("[#{elapsed}s] #{msg}")
end

# Affected: obs whose own vote_cache is ~0/nil but which has a Naming
# at the same name with a real positive vote_cache.
def affected_observation_ids
  sql = <<~SQL.squish
    SELECT obs.id
    FROM observations obs
    JOIN namings n ON n.observation_id = obs.id AND n.name_id = obs.name_id
    WHERE ABS(IFNULL(obs.vote_cache, 0)) < 0.01
      AND IFNULL(n.vote_cache, 0) > 0.01
  SQL
  ActiveRecord::Base.connection.select_values(sql)
end

def recompute_consensus_for(obs)
  Observation::NamingConsensus.new(obs).calc_consensus
end

EPSILON = 1e-4

# nil and 0.0 are equivalent for our purposes (both mean "no useful
# vote_cache recorded"); coerce to compare cleanly.
def vote_cache_changed?(before, after)
  (before.to_f - after.to_f).abs > EPSILON
end

def dry_run_process(obs, obs_id)
  consensus = Observation::NamingConsensus.new(obs)
  calc = Observation::ConsensusCalculator.new(consensus.namings)
  _best, val = calc.calc(User.current)
  return :unchanged unless val.to_f.abs > EPSILON

  log("  obs #{obs_id}: 0.0 → #{val.round(3)}") if VERBOSE
  :repaired
end

def live_process(obs, obs_id)
  before = obs.vote_cache
  recompute_consensus_for(obs)
  obs.reload
  return :unchanged unless vote_cache_changed?(before, obs.vote_cache)

  log("  obs #{obs_id} repaired") if VERBOSE
  :repaired
end

# Returns :repaired or :unchanged for tally bookkeeping.
def process_obs(obs, obs_id)
  DRY_RUN ? dry_run_process(obs, obs_id) : live_process(obs, obs_id)
end

ids = affected_observation_ids
log("Found #{ids.size} observations with stale vote_cache")

tally = { repaired: 0, unchanged: 0, missing: 0, errors: 0 }
ids.each_with_index do |obs_id, i|
  log("  #{i}/#{ids.size} processed") if (i % 200).zero? && i.positive?

  obs = Observation.find_by(id: obs_id)
  if obs.nil?
    tally[:missing] += 1
    log("  ? obs #{obs_id} disappeared between query and load")
    next
  end

  tally[process_obs(obs, obs_id)] += 1
rescue StandardError => e
  tally[:errors] += 1
  log("  ! obs #{obs_id}: #{e.class}: #{e.message}")
end

log("=" * 60)
verb = DRY_RUN ? "would be repaired" : "repaired"
log("Done: #{tally[:repaired]} #{verb}, " \
    "#{tally[:unchanged]} unchanged, #{tally[:missing]} missing, " \
    "#{tally[:errors]} errors in #{elapsed}s")
