# frozen_string_literal: true

# Make Observation#collector the single source of truth for collector
# identity (#4211): seed the column from the legacy notes keys, remove the
# canonical :Collector key from notes, then strip the now-forbidden
# "Collector" heading from user notes_templates.
#
# This is a data migration rather than a runner script on purpose. The
# three changes must land atomically with the code that depends on them:
# the moment the new code deploys, the collector_from_notes fallback is
# gone and User validation forbids a "Collector" notes_template heading, so
# an un-migrated database would render blank collectors and block profile
# saves. script/deploy.sh runs migrations with puma stopped and the
# maintenance page up, so this work happens in a true offline window. See
# the discussion on PR #4452.
#
# Three idempotent passes (so a partial run, aborted mid-deploy, completes
# safely on the next deploy):
#
#   1. SEED — for every obs whose collector column is still blank, take a
#      collector value from notes in priority order (:Collector, then the
#      variants below), resolve a `_user <ref>_` markup to an MO user when
#      present (login then unique name), and set collector (+ FK). Free
#      text is stored verbatim with a null FK.
#
#   2. STRIP NOTES — delete ONLY the canonical :Collector key from notes.
#      The variant keys are LEFT in place: after seeding they are treated
#      as independent user notes fields, not collector identity (#4211
#      decision C).
#
#   3. STRIP TEMPLATES — remove the now-forbidden exact "Collector" heading
#      from users' notes_template. Variant headings (e.g. "Collector's
#      Name") are independent fields and are left untouched.
#
# Irreversible: stripped notes/template values cannot be reconstructed.
class MigrateCollectorNotes < ActiveRecord::Migration[7.2]
  def up
    CollectorNotesMigrator.new(self).run
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end

  # Worker that performs the three passes. Uses update_columns /
  # update_column throughout to bypass callbacks and the new validations.
  class CollectorNotesMigrator
    BATCH_SIZE = 1_000
    COLLECTOR_KEY = :Collector
    # Legacy variants that also held collector identity. Used to seed the
    # column; NOT stripped from notes (kept as independent fields).
    VARIANT_KEYS = [:collector, :"Collector's_Name", :"Collector's_name",
                    :"Collector(s)"].freeze
    SEED_KEYS = [COLLECTOR_KEY, *VARIANT_KEYS].freeze
    # Capture the ref between "_user " and the closing "_" delimiter.
    # Non-greedy, but the closing "_" must be followed by a non-word
    # char or end-of-string, so logins/names containing underscores
    # survive ("_user tyler_irvin_" -> "tyler_irvin", not "tyler")
    # while trailing markup after the ref isn't over-captured
    # ("_user joe_ and _user bob_" -> "joe"). See #4211 review.
    USER_MARKUP = /_user\s+(.+?)_(?=\W|\z)/
    SEEDED_LOG = Rails.root.join("log/collector_notes_seeded.tsv")
    UNRESOLVED_LOG = Rails.root.join("log/collector_notes_unresolved.tsv")

    def initialize(migration)
      @migration = migration
      @seeded = []
      @unresolved = []
      @stripped = 0
      @templates_changed = 0
      @started_at = Time.current
    end

    def run
      seed_column
      strip_collector_note
      strip_user_templates
      write_logs
      print_summary
    end

    private

    # Route progress through the migration's `say` so it shows up in the
    # `rake db:migrate` output during deploy (and satisfies Rails/Output).
    def log(message, subitem: false)
      @migration.say(message, subitem)
    end

    def sub(message)
      log(message, subitem: true)
    end

    # --- Pass 1: seed the column from notes where it is still blank ---

    def seed_column
      scope = Observation.where("notes LIKE ?", "%ollector%").
              where(collector: [nil, ""])
      log("Pass 1 (seed): #{scope.count} obs with a collector-ish note")
      scope.in_batches(of: BATCH_SIZE) { |batch| batch.each { |o| seed(o) } }
    end

    def seed(obs)
      key = SEED_KEYS.find { |k| obs.notes[k].to_s.strip.present? }
      return unless key

      collector, user_id = resolve(obs, obs.notes[key].to_s)
      @seeded << { id: obs.id, key: key, linked: !user_id.nil? }
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
      log("Pass 2 (strip notes): scanning #{scope.count} obs")
      scope.in_batches(of: BATCH_SIZE) { |batch| batch.each { |o| strip(o) } }
    end

    def strip(obs)
      return unless obs.notes.key?(COLLECTOR_KEY)

      @stripped += 1
      obs.update_columns(notes: obs.notes.except(COLLECTOR_KEY))
    end

    # --- Pass 3: strip the forbidden "Collector" template heading ---

    def strip_user_templates
      scope = User.where("notes_template LIKE ?", "%Collector%")
      log("Pass 3 (strip templates): scanning #{scope.count} users")
      scope.find_each { |user| strip_template(user) }
    end

    def strip_template(user)
      parts = user.notes_template.to_s.split(",").map(&:squish)
      return unless parts.include?("Collector")

      kept = parts.reject { |part| part == "Collector" }.join(", ")
      @templates_changed += 1
      log("user #{user.id} #{user.login}: " \
          "#{user.notes_template.inspect} -> #{kept.inspect}", subitem: true)
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
      log("Done in #{elapsed}s.")
      sub("Seeded column on #{@seeded.size} obs (#{linked} linked).")
      sub("Stripped :Collector from #{@stripped} obs' notes.")
      sub("Stripped 'Collector' from #{@templates_changed} templates.")
      sub("#{@unresolved.size} _user refs unresolved (stored as text).")
      sub("Logs: #{SEEDED_LOG}, #{UNRESOLVED_LOG}") if @seeded.any?
    end
  end
end
