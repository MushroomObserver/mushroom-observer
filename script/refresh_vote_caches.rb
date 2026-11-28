# frozen_string_literal: true

# rubocop:disable MO/NoLongCommentBlock
# The data half of 20261128120000_convert_float_columns_to_double.
#
# Widening a column is exact, so every naming and observation kept
# the value single precision had rounded it to: 0.5799999833106995
# where a fresh computation gives 0.58. Ordering and display do not
# notice the difference, but a filter comparing against a decimal the
# user typed does -- `Naming.confidence(2.4)` is
# `where(vote_cache: 2.4..2.4)`, which misses a row holding
# 2.4000000953674316. Measured over 500 observations: three fifths of
# the namings and over half the observations differ from a fresh
# computation.
#
# The migration recomputed the image averages itself, since that is
# one group-by. This one needs Observation::ConsensusCalculator per
# observation, about 5ms each and near an hour over the table, so it
# runs out of band with the site up rather than inside the deploy.
# Idempotent: a row already holding the computed value is left alone,
# so a re-run after an interruption costs only the reading.
#
# Numbers only. An observation whose consensus name no longer matches
# the name on the row is left untouched and reported -- that is a
# different repair, and this script writes `vote_cache` through
# `update_all`, so no name, timestamp, `needs_naming` or notification
# moves either way.
#
# Dry run (default -- reports, writes nothing):
#   bin/rails runner script/refresh_vote_caches.rb
# Apply:
#   bin/rails runner script/refresh_vote_caches.rb --apply
# rubocop:enable MO/NoLongCommentBlock

APPLY = ARGV.delete("--apply") ? true : false
if ARGV.any?
  warn("Unknown argument(s): #{ARGV.join(", ")}")
  warn("Usage: bin/rails runner script/refresh_vote_caches.rb [--apply]")
  exit(1)
end

# Recomputes naming and observation vote caches at double precision.
class VoteCacheRefresh
  BATCH = 500
  REPORT_EVERY = 10_000
  MISMATCH_SAMPLE = 20
  REPORT_DIR = "projects/5811"

  def initialize(apply:)
    @apply = apply
    @counts = Hash.new(0)
    @mismatched = []
    @started = Time.zone.now
  end

  def run
    total = scope.count
    warn("#{total} observations carry a naming")
    done = 0
    # The calculator saves each naming it recomputes, and a vote cache
    # is derived data: hold updated_at still, as Image#change_vote
    # does for the same reason.
    Naming.record_timestamps = false
    scope.in_batches(of: BATCH) do |batch|
      refresh(batch)
      done += BATCH
      progress([done, total].min, total)
    end
    report
  ensure
    Naming.record_timestamps = true
  end

  private

  def scope
    Observation.where(id: Naming.select(:observation_id))
  end

  def refresh(batch)
    ActiveRecord::Base.transaction do
      observations = batch.to_a
      ids = observations.map(&:id)
      before = naming_caches(ids)
      updates = observations.filter_map { |obs| recompute(obs) }
      @counts[:namings] += changed_namings(ids, before)
      write(updates)
      raise(ActiveRecord::Rollback) unless @apply
    end
  end

  # The calculator refreshes each naming's cache as it goes; what
  # comes back is the winning naming and its value, which is what the
  # observation caches.
  def recompute(observation)
    best, best_value = Observation::ConsensusCalculator.
                       new(observation.namings).calc(User.admin)
    return mismatch(observation) if best&.id != observation.name_id
    return nil if observation.vote_cache == best_value

    [observation.id, best_value]
  end

  def mismatch(observation)
    @mismatched << observation.id
    nil
  end

  def write(updates)
    updates.group_by(&:last).each do |value, pairs|
      Observation.where(id: pairs.map(&:first)).
        update_all(vote_cache: value)
      @counts[:observations] += pairs.size
    end
  end

  def naming_caches(ids)
    Naming.where(observation_id: ids).pluck(:id, :vote_cache).to_h
  end

  def changed_namings(ids, before)
    naming_caches(ids).count { |id, value| before[id] != value }
  end

  def progress(done, total)
    return unless (done % REPORT_EVERY).zero? || done == total

    elapsed = Time.zone.now - @started
    warn(format("%d/%d observations, %.0fs elapsed, %.0f/s",
                done, total, elapsed, done / elapsed))
  end

  def report
    warn("#{@counts[:namings]} naming vote caches recomputed")
    warn("#{@counts[:observations]} observation vote caches recomputed")
    report_mismatches
    return if @apply

    warn("Dry run - nothing written. To apply: bundle exec rails runner " \
         "script/refresh_vote_caches.rb --apply")
  end

  def report_mismatches
    return warn("0 observations skipped") if @mismatched.empty?

    warn("#{@mismatched.size} observation(s) skipped, consensus name " \
         "differs from the name on the row: " \
         "#{@mismatched.first(MISMATCH_SAMPLE).join(", ")}")
    return if @mismatched.size <= MISMATCH_SAMPLE

    FileUtils.mkdir_p(REPORT_DIR)
    path = File.join(REPORT_DIR, "consensus_name_mismatches.txt")
    File.write(path, "#{@mismatched.join("\n")}\n")
    warn("full list: #{path}")
  end
end

VoteCacheRefresh.new(apply: APPLY).run
