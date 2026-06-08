#!/usr/bin/env ruby
# frozen_string_literal: true

# Make Observation#collector the single source of truth for collector
# identity (#4211): seed the column from the legacy notes keys, then
# remove the canonical :Collector key from notes.
#
#   bin/rails runner script/migrate_collector_notes.rb           # apply
#   DRY_RUN=1 bin/rails runner script/migrate_collector_notes.rb # report
#
# Two idempotent passes:
#
#   1. SEED — for every obs whose collector column is still blank, take a
#      collector value from notes in priority order (:Collector, then the
#      variants below), resolve a `_user <ref>_` markup to an MO user when
#      present (login then unique name), and set collector (+ FK). Free
#      text is stored verbatim with a null FK.
#
#   2. STRIP — delete ONLY the canonical :Collector key from notes
#      everywhere it appears. The variant keys are LEFT in place: after
#      seeding they are treated as independent user notes fields, not as
#      collector identity. See #4211 (decision C).
#
# Re-running is safe: pass 1 skips rows that already have a collector,
# pass 2 skips rows with no :Collector key. Seeded-from-variant rows and
# unresolved markup refs are written to the logs below.
class CollectorNotesMigration
  BATCH_SIZE = 1_000
  COLLECTOR_KEY = :Collector
  # Legacy variants that also held collector identity. Used to seed the
  # column; NOT stripped from notes (kept as independent fields).
  VARIANT_KEYS = [:collector, :"Collector's_Name", :"Collector's_name",
                  :"Collector(s)"].freeze
  SEED_KEYS = [COLLECTOR_KEY, *VARIANT_KEYS].freeze
  # Greedy capture up to the LAST underscore so logins containing
  # underscores survive (e.g. "_user tyler_irvin_" -> "tyler_irvin",
  # not "tyler"). See #4211 review.
  USER_MARKUP = /_user\s+(.+)_/
  SEEDED_LOG = Rails.root.join("log/collector_notes_seeded.tsv")
  UNRESOLVED_LOG = Rails.root.join("log/collector_notes_unresolved.tsv")

  def initialize
    @dry_run = ENV["DRY_RUN"].present?
    @seeded = []
    @unresolved = []
    @stripped = 0
    @started_at = Time.current
  end

  def run
    banner
    seed_column
    strip_collector_note
    write_logs
    print_summary
  end

  private

  def banner
    mode = @dry_run ? "DRY RUN (no writes)" : "APPLYING"
    puts("Collector notes migration — #{mode}")
  end

  # --- Pass 1: seed the column from notes where it is still blank ---

  def seed_column
    scope = Observation.where("notes LIKE ?", "%ollector%").
            where(collector: [nil, ""])
    total = scope.count
    puts("Pass 1 (seed): #{total} obs with a collector-ish note, blank column")
    scope.in_batches(of: BATCH_SIZE) { |batch| batch.each { |o| seed(o) } }
  end

  def seed(obs)
    key = SEED_KEYS.find { |note_key| obs.notes[note_key].to_s.strip.present? }
    return unless key

    value = obs.notes[key].to_s
    collector, user_id = resolve(obs, value)
    @seeded << { id: obs.id, key: key, linked: !user_id.nil? }
    return if @dry_run

    obs.update_columns(collector: collector, collector_user_id: user_id)
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

  # --- Pass 2: strip the canonical :Collector key from notes ---

  def strip_collector_note
    scope = Observation.where("notes LIKE ?", "%Collector%")
    total = scope.count
    puts("Pass 2 (strip): scanning #{total} obs for a :Collector note key")
    scope.in_batches(of: BATCH_SIZE) { |batch| batch.each { |o| strip(o) } }
  end

  def strip(obs)
    return unless obs.notes.key?(COLLECTOR_KEY)

    @stripped += 1
    return if @dry_run

    obs.update_columns(notes: obs.notes.except(COLLECTOR_KEY))
  end

  # --- Reporting ---

  def write_logs
    write_tsv(SEEDED_LOG, %w[observation_id source_key linked_to_user],
              @seeded.map { |r| [r[:id], r[:key], r[:linked]] })
    write_tsv(UNRESOLVED_LOG, %w[observation_id unresolved_ref],
              @unresolved.map { |r| [r[:id], r[:ref]] })
  end

  def write_tsv(path, header, rows)
    return if rows.empty?

    File.open(path, "w") do |f|
      f.puts(header.join("\t"))
      rows.each { |cols| f.puts(cols.join("\t")) }
    end
  end

  def print_summary
    elapsed = (Time.current - @started_at).round
    linked = @seeded.count { |r| r[:linked] }
    puts("\nDone in #{elapsed}s.")
    puts("  Seeded column on #{@seeded.size} obs (#{linked} linked to a user).")
    puts("  Stripped :Collector from #{@stripped} obs' notes.")
    puts("  #{@unresolved.size} _user refs unresolved (stored as plain text).")
    puts("  Logs: #{SEEDED_LOG}, #{UNRESOLVED_LOG}") if @seeded.any?
    puts("  DRY RUN — no changes were written.") if @dry_run
  end
end

CollectorNotesMigration.new.run
