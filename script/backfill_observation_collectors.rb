#!/usr/bin/env ruby
# frozen_string_literal: true

# Backfill Observation#collector / #collector_user_id from the legacy
# notes[:Collector] value, where collector identity lived before #4211.
# Run once after the add_collector_to_observations migration ships.
# Idempotent — safe to re-run (skips rows that already have a collector).
#
#   bin/rails runner script/backfill_observation_collectors.rb
#
# For each obs carrying a Collector note: extract the first `_user <ref>_`
# textile markup (tolerant of surrounding/internal whitespace and
# embedding), resolve <ref> to an MO user by login then unique name, and
# set collector_user_id + collector (the user's unique_text_name) when it
# resolves. Otherwise store the cleaned note string and leave the FK null
# — FK population is restricted to explicit `_user …_` markup so free-text
# collector strings (mostly iNat fields) aren't mis-linked to a
# coincidentally-named MO user. notes is left unchanged (imported
# snapshots stay verbatim for #4214; the show page suppresses the dup).
#
# Unresolved markup rows are written to UNRESOLVED_LOG (obs id + ref) and
# logged, so the manual-follow-up list survives the run.
#
# See app/models/observation.rb (collector_textile / collector_from_notes)
# and app/helpers/observations_helper.rb (the show-page Collector line).

class ObservationCollectorBackfill
  BATCH_SIZE = 1_000
  USER_MARKUP = /_user\s+(.+?)_/
  UNRESOLVED_LOG = Rails.root.join("log/collector_backfill_unresolved.tsv")

  def initialize
    @processed = 0
    @linked = 0
    @unresolved = []
    @started_at = Time.current
  end

  def run
    total = scope.count
    puts("Backfilling collector across #{total} obs with a Collector note...")

    scope.in_batches(of: BATCH_SIZE) do |batch|
      batch.each { |obs| process(obs) }
      print_progress(total)
    end

    write_unresolved_log
    print_summary
  end

  private

  def scope
    Observation.where("notes LIKE ?", "%Collector%").where(collector: nil)
  end

  def process(obs)
    @processed += 1
    value = obs.notes[:Collector].to_s
    return if value.strip.blank?

    collector, collector_user_id = resolve(obs, value)
    obs.update_columns(collector: collector,
                       collector_user_id: collector_user_id)
    @linked += 1 if collector_user_id
  end

  # Returns [collector_string, collector_user_id].
  def resolve(obs, value)
    ref = value[USER_MARKUP, 1]
    return [clean(value), nil] if ref.nil?

    if (user = resolve_user(ref.strip))
      [user.unique_text_name, user.id]
    else
      @unresolved << { id: obs.id, ref: ref.strip }
      [clean(value), nil]
    end
  end

  def resolve_user(ref)
    User.find_by(login: ref) || unique_name_match(ref)
  end

  def unique_name_match(ref)
    named = User.where(name: ref)
    named.one? ? named.first : nil
  end

  def clean(value)
    value.to_s.strip[0, 1024]
  end

  def write_unresolved_log
    return if @unresolved.empty?

    File.open(UNRESOLVED_LOG, "w") do |f|
      f.puts("observation_id\tunresolved_ref")
      @unresolved.each { |row| f.puts("#{row[:id]}\t#{row[:ref]}") }
    end
    @unresolved.each do |row|
      Rails.logger.warn(
        "collector backfill: obs #{row[:id]} _user markup " \
        "#{row[:ref].inspect} did not resolve; stored as plain text"
      )
    end
  end

  def print_progress(total)
    pct = (@processed.to_f / total * 100).round(1)
    elapsed = (Time.current - @started_at).round
    print("\r  #{@processed}/#{total} (#{pct}%) in #{elapsed}s")
    $stdout.flush
  end

  def print_summary
    elapsed = (Time.current - @started_at).round
    puts("\nDone in #{elapsed}s. Linked #{@linked} rows to an MO user.")
    return if @unresolved.empty?

    puts("#{@unresolved.size} _user markup refs did not resolve " \
         "(stored as plain text). See #{UNRESOLVED_LOG}.")
  end
end

ObservationCollectorBackfill.new.run
