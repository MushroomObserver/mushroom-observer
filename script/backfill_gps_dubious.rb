#!/usr/bin/env ruby
# frozen_string_literal: true

# Backfill Observation#gps_dubious for every obs with a recorded GPS
# and a location. Run once after the add_gps_dubious_to_observations
# migration ships. Idempotent — safe to re-run (only writes rows
# whose computed value differs from the stored one).
#
#   bin/rails runner script/backfill_gps_dubious.rb
#
# Issue #4159 — see app/models/observation.rb#set_gps_dubious and
# Mappable::BoxMethods#km_from_point for the underlying predicate.

require "English"

class GpsDubiousBackfill
  BATCH_SIZE = 1_000

  def initialize
    @processed = 0
    @flagged = 0
    @started_at = Time.current
  end

  def run
    total = scope.count
    puts("Backfilling gps_dubious across #{total} obs...")

    scope.includes(:location).in_batches(of: BATCH_SIZE) do |batch|
      batch.each { |obs| process(obs) }
      print_progress(total)
    end

    elapsed = (Time.current - @started_at).round
    puts("\nDone. Changed #{@flagged} rows (net flagged) in #{elapsed}s.")
  end

  private

  def scope
    Observation.where.not(lat: nil).where.not(lng: nil).
      where.not(location_id: nil)
  end

  def process(obs)
    @processed += 1
    computed = obs.compute_gps_dubious?
    return if computed == obs.gps_dubious

    obs.update_column(:gps_dubious, computed)
    @flagged += 1 if computed
  end

  def print_progress(total)
    pct = (@processed.to_f / total * 100).round(1)
    elapsed = (Time.current - @started_at).round
    print("\r  #{@processed}/#{total} (#{pct}%) in #{elapsed}s")
    $stdout.flush
  end
end

GpsDubiousBackfill.new.run
