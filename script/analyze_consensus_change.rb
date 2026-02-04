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
#  With --update, recalculates consensus for all observations using
#  the new algorithm and saves the results. Updates both naming
#  vote_cache values and observation consensus name/vote_cache.
#
#  Options:
#    --limit N   Only process the first N observations
#    --update    Recalculate and save consensus for all observations

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
  ARGV.each_with_index do |arg, i|
    limit = ARGV[i + 1].to_i if arg == "--limit"
    update = true if arg == "--update"
  end
  [limit, update]
end

def obs_scope
  Observation.includes(
    :name,
    namings: [:name, { votes: [:observation, :user] }]
  )
end

def print_progress(processed, total, change_count)
  return unless (processed % 5000).zero?

  $stdout.print(
    "\r  #{processed}/#{total} processed, " \
    "#{change_count} changed..."
  )
  $stdout.flush
end

def print_summary(processed, changes, errors)
  puts("\r#{" " * 60}\r")
  puts("Processed: #{processed}")
  puts("Changed consensus: #{changes.count}")
  puts("Unchanged: #{processed - changes.count - errors}")
  puts("Errors: #{errors}")
  puts
  print_changes(changes)
end

def print_changes(changes)
  return unless changes.any?

  puts("=" * 72)
  puts("Observations with changed consensus name:")
  puts("=" * 72)
  changes.each do |c|
    puts("  #{BASE_URL}/obs/#{c[:obs_id]}")
    puts("    #{c[:old_name]} -> #{c[:new_name]}")
  end
end

def record_change(obs_id, old_name, new_name)
  {
    obs_id: obs_id,
    old_name: old_name&.real_search_name || "(none)",
    new_name: new_name&.real_search_name || "(none)"
  }
end

# Shared processing loop for both modes.
# Yields each observation and a changes array to the block.
def process_observations(scope, total, limit = nil)
  changes = []
  processed = 0
  errors = 0

  scope.find_each do |obs|
    break if limit && processed >= limit

    yield(obs, changes)

    processed += 1
    print_progress(processed, total, changes.count)
  rescue StandardError => e
    errors += 1
    warn("Error on obs ##{obs.id}: #{e.message}")
  end

  print_summary(processed, changes, errors)
end

def find_candidate_ids
  Vote.connection.select_values(<<~SQL.squish)
    SELECT DISTINCT sub.observation_id
    FROM (
      SELECT observation_id, user_id, MAX(value) AS max_val
      FROM votes
      GROUP BY observation_id, user_id
      HAVING max_val > 0 AND max_val < #{Vote::MAXIMUM_VOTE}
    ) sub
    INNER JOIN namings n1
      ON n1.observation_id = sub.observation_id
    INNER JOIN namings n2
      ON n2.observation_id = sub.observation_id
      AND n2.id != n1.id
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

def compare_consensus(obs, changes)
  old_name, = OldCalculator.new(obs.namings).calc(nil)
  new_name, = ReadOnlyCalculator.new(obs.namings).calc(nil)
  return if old_name&.id == new_name&.id

  changes << record_change(obs.id, old_name, new_name)
end

def analyze_candidates(limit)
  ids = prepared_candidate_ids(limit)
  scope = obs_scope.where(id: ids)
  process_observations(scope, ids.count) do |obs, ch|
    compare_consensus(obs, ch)
  end
end

def update_observation(obs, best, best_val)
  return if obs.name_id == best&.id &&
            obs.vote_cache == best_val

  needs_naming =
    !best.above_genus? && best_val&.positive? ? 0 : 1
  obs.update(name: best, vote_cache: best_val,
             needs_naming: needs_naming)
end

def recalculate_observation(obs, changes)
  old_name = obs.name
  calc = Observation::ConsensusCalculator.new(obs.namings)
  best, best_val = calc.calc(nil)
  update_observation(obs, best, best_val)
  return if old_name&.id == best&.id

  changes << record_change(obs.id, old_name, best)
end

def print_update_counts(limit)
  total = Observation.count
  processing = limit || total
  puts("Total observations: #{total}")
  puts("Processing: #{processing}")
  processing
end

def update_all_observations(limit)
  processing = print_update_counts(limit)
  process_observations(obs_scope, processing, limit) do |obs, ch|
    recalculate_observation(obs, ch)
  end
end

limit, update = parse_args
if update
  update_all_observations(limit)
else
  analyze_candidates(limit)
end
