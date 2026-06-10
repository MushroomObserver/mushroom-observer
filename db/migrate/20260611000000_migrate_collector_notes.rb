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
#      value from notes in priority order (:Collector, then the name
#      variants, then "Collector(s)") and run it through
#      Observation.resolve_collector (markup / iNat username / login /
#      unique name), with a fuzzy owner-name match layered on so a
#      reformatted version of the entering user's own name links to them.
#      What gets seeded then depends on the source key (see PR #4452):
#      a value linked to an MO user is always seeded; canonical :Collector
#      free text is seeded verbatim; a name-variant value is seeded as free
#      text only when it is a single, non-junk person name (lists, junk
#      placeholders, and long sentences are skipped); and "Collector(s)"
#      free text is never seeded (its values are often author lists).
#      Skipped values are logged for review, not lost (the note stays).
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
    # Legacy variant keys that also held collector identity, in seed
    # priority order. NOT stripped from notes (kept as independent fields).
    # The lowercase ":collector" key (a single junk row) is intentionally
    # excluded. See the seeding policy in PR #4452.
    NAME_KEYS = [:"Collector's_Name", :"Collector's_name"].freeze
    # The listy "Collector(s)" field seeds ONLY when the value resolves to a
    # specific MO user; it never stores a free-text collector, because its
    # values are frequently multi-person author lists. See PR #4452.
    USER_ONLY_KEYS = [:"Collector(s)"].freeze
    SEED_KEYS = [COLLECTOR_KEY, *NAME_KEYS, *USER_ONLY_KEYS].freeze
    # A value naming more than one collector (a list), which we never seed.
    LIST_SEPARATORS = /[,&;+@]| and | et al/i
    # Non-name placeholders that should never become a collector.
    JUNK_VALUES = ["n/a", "na", "unknown", "none", "-", "?", ".", "various",
                   "multiple", "self", "me", "myself"].freeze
    MAX_NAME_LEN = 40
    SEEDED_LOG = Rails.root.join("log/collector_notes_seeded.tsv")
    UNRESOLVED_LOG = Rails.root.join("log/collector_notes_unresolved.tsv")
    SKIPPED_LOG = Rails.root.join("log/collector_notes_skipped.tsv")

    def initialize(migration)
      @migration = migration
      @seeded = []
      @unresolved = []
      @skipped = []
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

      value = obs.notes[key].to_s
      attrs = resolve(obs, value)
      return record_skip(obs, key, value) unless seedable?(key, value, attrs)

      apply_seed(obs, key, attrs)
    end

    def apply_seed(obs, key, attrs)
      @seeded << { id: obs.id, key: key,
                   linked: !attrs[:collector_user_id].nil? }
      obs.update_columns(collector: attrs[:collector],
                         collector_user_id: attrs[:collector_user_id])
    end

    # Whether a resolved value should populate the column:
    #   - linked to an MO user: always
    #   - canonical :Collector free text: yes (a deliberate collector field)
    #   - "Collector(s)" free text: no (user-only)
    #   - name-variant free text: only a single, non-junk person name
    def seedable?(key, value, attrs)
      return true if attrs[:collector_user_id]
      return false if USER_ONLY_KEYS.include?(key)
      return true if key == COLLECTOR_KEY

      single_person_name?(value)
    end

    def single_person_name?(value)
      v = value.strip
      v.length <= MAX_NAME_LEN && !v.match?(LIST_SEPARATORS) &&
        JUNK_VALUES.exclude?(v.downcase) && v.split.size <= 4
    end

    def record_skip(obs, key, value)
      @skipped << { id: obs.id, key: key, value: value.strip[0, 120] }
    end

    # Returns { collector:, collector_user_id: } from the shared resolver
    # (markup / owner / iNat username / login / unique name), then layers a
    # fuzzy owner-name match so a reformatted version of the entering user's
    # own name ("Alden C. Dirks" for owner aldendirks) links to the owner.
    def resolve(obs, value)
      attrs = Observation.resolve_collector(value, owner: obs.user,
                                                   match_inat: true)
      return attrs if attrs[:collector_user_id]
      return Observation.collector_attrs(obs.user) if fuzzy_owner?(obs, attrs)

      note_unresolved_markup(obs, value)
      attrs
    end

    def fuzzy_owner?(obs, attrs)
      obs.user && fuzzy_owner_match?(attrs[:collector], obs.user)
    end

    def note_unresolved_markup(obs, value)
      ref = value[Observation::COLLECTOR_USER_MARKUP, 1]
      @unresolved << { id: obs.id, ref: ref.strip } if ref
    end

    # A reformatted version of the owner's own name: every non-initial token
    # of the shorter name appears in the longer ("Alden Dirks" matches
    # "Alden C. Dirks"). Middle initials are dropped before comparing.
    def fuzzy_owner_match?(value, owner)
      tokens = name_tokens(value)
      return false if tokens.empty?

      owner_token_sets(owner).any? do |other|
        next false if other.empty?

        short, long = if tokens.size <= other.size
                        [tokens,
                         other]
                      else
                        [other, tokens]
                      end
        (short - long).empty?
      end
    end

    def owner_token_sets(owner)
      [owner.name, owner.login, owner.unique_text_name].
        compact_blank.map { |str| name_tokens(str) }
    end

    def name_tokens(str)
      str.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").split.reject do |t|
        t.size <= 1
      end
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
      write_tsv(SKIPPED_LOG, %w[observation_id source_key skipped_value],
                @skipped.map { |r| [r[:id], r[:key], r[:value]] })
    end

    def write_tsv(path, header, rows)
      return if rows.empty?

      File.open(path, "w") do |f|
        f.puts(header.join("\t"))
        rows.each { |cols| f.puts(cols.join("\t")) }
      end
    end

    def print_summary
      log("Done in #{(Time.current - @started_at).round}s.")
      print_seed_summary
      sub("Stripped :Collector from #{@stripped} obs' notes.")
      sub("Stripped 'Collector' from #{@templates_changed} templates.")
      sub("#{@unresolved.size} _user refs unresolved (stored as text).")
      sub("Logs: #{SEEDED_LOG}, #{UNRESOLVED_LOG}, #{SKIPPED_LOG}")
    end

    def print_seed_summary
      linked = @seeded.count { |r| r[:linked] }
      sub("Seeded column on #{@seeded.size} obs " \
          "(#{linked} linked, #{@seeded.size - linked} free text).")
      sub("Skipped #{@skipped.size} list/junk/user-only variant values.")
    end
  end
end
