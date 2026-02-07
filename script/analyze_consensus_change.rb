# frozen_string_literal: true

#  USAGE::
#
#    rails runner script/analyze_consensus_change.rb [options]
#
#  DESCRIPTION::
#
#  Analyzes or applies the consensus algorithm change (Issue #3815).
#
#  Without --update, compares old vs new consensus for candidate
#  observations (those with multiple namings and sub-max voters).
#  Makes NO changes to the database.
#
#  With --update, recalculates consensus for boost-affected
#  observations using the new algorithm, but ONLY saves updates that
#  do NOT change the consensus name. This updates vote_cache values
#  (which affect confidence ordering) while preserving existing
#  consensus names. Observations that would have their names changed
#  are listed for manual review.
#
#  Options:
#    --limit N    Only process the first N observations
#    --update     Update vote_cache for observations where name won't change
#    --output F   Write list of would-change observations to file F

BASE_URL = "https://mushroomobserver.org"

# Read-only calculator that skips vote_cache updates.
class ReadOnlyCalculator < Observation::ConsensusCalculator
  private

  def update_naming_cache(_naming, _value); end
end

# Old algorithm: effective_weight always returns full weight.
class OldCalculator < ReadOnlyCalculator
  private

  def effective_weight(_user_id, _val, wgt, _naming_id)
    wgt
  end
end

def parse_args
  limit = nil
  update = false
  output_file = nil
  ARGV.each_with_index do |arg, i|
    limit = ARGV[i + 1].to_i if arg == "--limit"
    update = true if arg == "--update"
    output_file = ARGV[i + 1] if arg == "--output"
  end
  [limit, update, output_file]
end

def obs_scope
  Observation.includes(
    :name,
    namings: [:name, { votes: [:observation, :user] }]
  )
end

def format_time(time)
  time.strftime("%Y-%m-%d %H:%M:%S")
end

def estimate_end_time(start_time, processed, total)
  return nil if processed.zero?

  elapsed = Time.zone.now - start_time
  rate = processed.to_f / elapsed
  remaining = (total - processed) / rate
  Time.zone.now + remaining
end

def print_progress(processed, total, change_count, start_time)
  return unless (processed % 5000).zero?

  now = Time.zone.now
  elapsed = format_duration(now - start_time)
  eta = estimate_end_time(start_time, processed, total)
  eta_str = eta ? " | ETA: #{format_time(eta)}" : ""
  puts(
    "[#{format_time(now)}] #{processed}/#{total} processed, " \
    "#{change_count} would change | elapsed: #{elapsed}#{eta_str}"
  )
end

def format_duration(seconds)
  hours = (seconds / 3600).to_i
  minutes = ((seconds % 3600) / 60).to_i
  secs = (seconds % 60).to_i
  format("%<h>02d:%<m>02d:%<s>02d", h: hours, m: minutes, s: secs)
end

def print_timing(start_time, end_time)
  return unless start_time && end_time

  elapsed = end_time - start_time
  puts("Finished at: #{format_time(end_time)}")
  puts("Elapsed: #{format_duration(elapsed)}")
  puts
end

def count_unchanged(stats)
  stats[:processed] - stats[:changes].count - stats[:updated] - stats[:errors]
end

def print_counts(stats)
  puts("Processed: #{stats[:processed]}")
  puts("Would change consensus name: #{stats[:changes].count}")
  if stats[:updated].positive?
    puts("Updated (vote_cache only): #{stats[:updated]}")
  end
  puts("Unchanged: #{count_unchanged(stats)}")
  puts("Errors: #{stats[:errors]}")
end

def print_summary(stats)
  puts
  print_timing(stats[:start_time], stats[:end_time])
  print_counts(stats)
  puts
  print_changes(stats[:changes])
end

def print_changes(changes)
  return unless changes.any?

  puts("=" * 72)
  puts("Observations that would change consensus name (requires review):")
  puts("=" * 72)
  changes.each do |c|
    puts("  #{BASE_URL}/obs/#{c[:obs_id]}")
    puts("    #{c[:old_name]} -> #{c[:new_name]}")
  end
end

def changes_file_header
  <<~HEADER
    # Observations Requiring Review

    The following observations would have their consensus name
    changed by the updated algorithm. Please review these observations
    and vote on them if you have relevant knowledge.

    | Observation | Current Name | New Name |
    |-------------|--------------|----------|
  HEADER
end

def format_change_row(change)
  obs_link = "[#{change[:obs_id]}](#{BASE_URL}/obs/#{change[:obs_id]})"
  "| #{obs_link} | #{change[:old_name]} | #{change[:new_name]} |"
end

def write_changes_to_file(changes, output_file)
  return unless output_file && changes.any?

  File.open(output_file, "w") do |f|
    f.write(changes_file_header)
    changes.each { |c| f.puts(format_change_row(c)) }
  end
  puts
  puts("Wrote #{changes.count} observations to: #{output_file}")
end

def record_change(obs_id, old_name, new_name)
  {
    obs_id: obs_id,
    old_name: old_name&.real_search_name || "(none)",
    new_name: new_name&.real_search_name || "(none)"
  }
end

def print_start_time
  start_time = Time.zone.now
  puts("Started at: #{format_time(start_time)}")
  puts
  start_time
end

def build_stats(result, processed, errors, start_time)
  {
    changes: result[:changes],
    updated: result[:updated],
    processed: processed,
    errors: errors,
    start_time: start_time,
    end_time: Time.zone.now
  }
end

# Shared processing loop for both modes.
# Yields each observation and a result hash to the block.
# Result hash has :changes (name would change) and :updated (vote_cache updated)
def process_observations(scope, total, limit: nil, output_file: nil)
  start_time = print_start_time
  result = { changes: [], updated: 0 }
  processed = 0
  errors = 0

  scope.find_each do |obs|
    break if limit && processed >= limit

    yield(obs, result)

    processed += 1
    print_progress(processed, total, result[:changes].count, start_time)
  rescue StandardError => e
    errors += 1
    warn("Error on obs ##{obs.id}: #{e.message}")
  end

  stats = build_stats(result, processed, errors, start_time)
  print_summary(stats)
  write_changes_to_file(stats[:changes], output_file)
end

# Find observations where the boost actually applies.
# Encodes all 4 conditions from boost_vote?:
#   1. User's max vote across all namings is positive
#   2. User's max vote < MAXIMUM_VOTE
#   3. The vote equals the user's max
#   4. The naming has a higher vote from someone else
def find_boost_affected_ids
  Vote.connection.select_values(<<~SQL.squish)
    SELECT DISTINCT v.observation_id
    FROM votes v
    INNER JOIN (
      SELECT observation_id, user_id,
             MAX(value) AS user_max
      FROM votes
      GROUP BY observation_id, user_id
      HAVING user_max > 0
        AND user_max < #{Vote::MAXIMUM_VOTE}
    ) user_maxes
      ON v.observation_id = user_maxes.observation_id
      AND v.user_id = user_maxes.user_id
      AND v.value = user_maxes.user_max
    INNER JOIN (
      SELECT naming_id, MAX(value) AS naming_max
      FROM votes
      GROUP BY naming_id
    ) naming_maxes
      ON v.naming_id = naming_maxes.naming_id
      AND naming_maxes.naming_max > v.value
  SQL
end

# For analysis mode, also require multiple namings since
# single-naming observations can't change consensus name.
def find_candidate_ids
  ids = find_boost_affected_ids
  return [] if ids.empty?

  Vote.connection.select_values(<<~SQL.squish)
    SELECT DISTINCT n1.observation_id
    FROM namings n1
    INNER JOIN namings n2
      ON n2.observation_id = n1.observation_id
      AND n2.id != n1.id
    WHERE n1.observation_id IN (#{ids.join(',')})
  SQL
end

def prepared_candidate_ids(limit)
  ids = find_candidate_ids
  total = ids.count
  ids = ids.first(limit) if limit
  puts("Candidate observations: #{total}")
  puts("Processing: #{ids.count}")
  ids
end

def compare_consensus(obs, result)
  old_name, = OldCalculator.new(obs.namings).calc(nil)
  new_name, = ReadOnlyCalculator.new(obs.namings).calc(nil)
  return if old_name&.id == new_name&.id

  result[:changes] << record_change(obs.id, old_name, new_name)
end

def analyze_candidates(limit, output_file)
  ids = prepared_candidate_ids(limit)
  scope = obs_scope.where(id: ids)
  process_observations(scope, ids.count,
                       limit: nil, output_file: output_file) do |obs, result|
    compare_consensus(obs, result)
  end
end

# Update observation only if name stays the same.
# Returns :updated if vote_cache was updated, :changed if name would change,
# or nil if no update needed.
def update_observation_if_safe(obs, best, best_val)
  name_matches = obs.name_id == best&.id
  vote_cache_matches = obs.vote_cache == best_val

  # If name would change, don't update - return :changed for tracking
  return :changed unless name_matches

  # If vote_cache already matches, nothing to do
  return nil if vote_cache_matches

  # Name matches but vote_cache differs - safe to update
  needs_naming =
    !best.above_genus? && best_val&.positive? ? 0 : 1
  obs.update(vote_cache: best_val, needs_naming: needs_naming)
  :updated
end

def recalculate_observation(obs, result)
  old_name = obs.name
  calc = Observation::ConsensusCalculator.new(obs.namings)
  best, best_val = calc.calc(nil)
  status = update_observation_if_safe(obs, best, best_val)

  case status
  when :updated
    result[:updated] += 1
  when :changed
    result[:changes] << record_change(obs.id, old_name, best)
  end
end

def prepared_boost_ids(limit)
  ids = find_boost_affected_ids
  total = ids.count
  ids = ids.first(limit) if limit
  puts("Boost-affected observations: #{total}")
  puts("Processing: #{ids.count}")
  puts("Mode: Update vote_cache only where consensus name unchanged")
  ids
end

def update_all_observations(limit, output_file)
  ids = prepared_boost_ids(limit)
  scope = obs_scope.where(id: ids)
  process_observations(scope, ids.count,
                       limit: nil,
                       output_file: output_file) do |obs, result|
    recalculate_observation(obs, result)
  end
end

limit, update, output_file = parse_args
if update
  update_all_observations(limit, output_file)
else
  analyze_candidates(limit, output_file)
end
