#!/usr/bin/env ruby
# frozen_string_literal: true

# Make Observation#collector the single source of truth for collector
# identity (#4211): seed the column from the legacy notes keys, remove the
# canonical :Collector key from notes, then strip the now-forbidden
# "Collector" heading from user notes_templates.
#
#   bin/rails runner script/migrate_collector_notes.rb           # apply
#   DRY_RUN=1 bin/rails runner script/migrate_collector_notes.rb # report
#
# Run exactly once, right after the add_collector_to_observations
# migration ships. The three passes are one logical change and must not be
# separated in time: the moment the code deploys, User validation forbids a
# "Collector" notes_template heading, so any user still carrying it has
# their next profile save blocked until pass 3 runs. Each pass is
# idempotent, so a partial run (or a staging-then-prod sequence) is safe to
# re-run.
#
# Three idempotent passes:
#
#   1. SEED — for every obs whose collector column is still blank, take a
#      collector value from notes in priority order (:Collector, then the
#      variants below), resolve a `_user <ref>_` markup to an MO user when
#      present (login then unique name), and set collector (+ FK). Free
#      text is stored verbatim with a null FK.
#
#   2. STRIP NOTES — delete ONLY the canonical :Collector key from notes
#      everywhere it appears. The variant keys are LEFT in place: after
#      seeding they are treated as independent user notes fields, not as
#      collector identity. See #4211 (decision C).
#
#   3. STRIP TEMPLATES — remove the now-forbidden exact "Collector" heading
#      from users' notes_template. Collector has its own observation column,
#      so it may no longer be a notes sub-heading; leaving it would block
#      the user's next profile save. Variant headings (e.g.
#      "Collector's Name") are independent fields and are left untouched.
#
# Re-running is safe: pass 1 skips rows that already have a collector, pass
# 2 skips rows with no :Collector key, pass 3 skips templates with no exact
# "Collector" part. Seeded-from-variant rows, unresolved markup refs, and
# changed templates are written to the logs below.
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
    @templates_changed = 0
    @started_at = Time.current
  end

  def run
    banner
    seed_column
    strip_collector_note
    strip_user_templates
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
    puts("Pass 2 (strip notes): scanning #{total} obs for a :Collector key")
    scope.in_batches(of: BATCH_SIZE) { |batch| batch.each { |o| strip(o) } }
  end

  def strip(obs)
    return unless obs.notes.key?(COLLECTOR_KEY)

    @stripped += 1
    return if @dry_run

    obs.update_columns(notes: obs.notes.except(COLLECTOR_KEY))
  end

  # --- Pass 3: strip the forbidden "Collector" heading from templates ---

  def strip_user_templates
    scope = User.where("notes_template LIKE ?", "%Collector%")
    puts("Pass 3 (strip templates): scanning #{scope.count} users' templates")
    scope.find_each { |user| strip_template(user) }
  end

  def strip_template(user)
    parts = user.notes_template.to_s.split(",").map(&:squish)
    return unless parts.include?("Collector")

    kept = parts.reject { |part| part == "Collector" }.join(", ")
    @templates_changed += 1
    puts("  user #{user.id} #{user.login}: " \
         "#{user.notes_template.inspect} -> #{kept.inspect}")
    return if @dry_run

    user.update_column(:notes_template, kept)
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
    puts("  Stripped 'Collector' from #{@templates_changed} user templates.")
    puts("  #{@unresolved.size} _user refs unresolved (stored as plain text).")
    puts("  Logs: #{SEEDED_LOG}, #{UNRESOLVED_LOG}") if @seeded.any?
    puts("  DRY RUN — no changes were written.") if @dry_run
  end
end

CollectorNotesMigration.new.run
