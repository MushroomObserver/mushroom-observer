# frozen_string_literal: true

# Seeds Observation#collector from the legacy notes keys (#4211 / PR #4452).
# Shared by the online pre-deploy backfill (script/backfill_collectors.rb)
# and the contract migration's idempotent safety pass.
#
# For every obs whose collector column is still blank, takes a value from
# notes in priority order (:Collector, then the name variants, then
# "Collector(s)") and runs it through Observation.resolve_collector (markup /
# iNat username / login / unique name), with a fuzzy owner-name match layered
# on so a reformatted version of the entering user's own name links to them.
# What gets seeded depends on the source key:
#   - a value linked to an MO user is always seeded;
#   - canonical :Collector free text is seeded verbatim;
#   - a name-variant value is seeded as free text only when it is a single,
#     non-junk person name (lists, junk placeholders, long sentences skipped);
#   - "Collector(s)" free text is never seeded (often author lists).
# Skipped values are logged for review, not lost (the note stays in place).
# Idempotent: only fills rows whose collector column is still blank.
class CollectorNotesSeeder
  BATCH_SIZE = 1_000
  COLLECTOR_KEY = :Collector
  # Legacy variant keys that also held collector identity, in seed priority
  # order. The lowercase ":collector" key (a single junk row) is excluded.
  NAME_KEYS = [:"Collector's_Name", :"Collector's_name"].freeze
  # The listy "Collector(s)" field seeds ONLY when the value resolves to a
  # specific MO user; it never stores free text (often author lists).
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

  attr_reader :seeded, :unresolved, :skipped

  # reporter: any object responding to #say(message, subitem) — the runner
  # passes a stdout shim, the migration passes itself. Nil stays silent.
  def initialize(reporter: nil)
    @reporter = reporter
    @seeded = []
    @unresolved = []
    @skipped = []
  end

  def run
    seed_column
    write_logs
    print_summary
    self
  end

  private

  def say(message, subitem: false)
    @reporter&.say(message, subitem)
  end

  def sub(message)
    say(message, subitem: true)
  end

  def seed_column
    scope = Observation.where("notes LIKE ?", "%ollector%").
            where(collector: [nil, ""])
    say("Seeding: #{scope.count} obs with a collector-ish note")
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

  # A reformatted version of the owner's own name: every non-initial token of
  # the shorter name appears in the longer ("Alden Dirks" matches "Alden C.
  # Dirks"). Middle initials are dropped before comparing.
  def fuzzy_owner_match?(value, owner)
    tokens = name_tokens(value)
    return false if tokens.empty?

    owner_token_sets(owner).any? do |other|
      next false if other.empty?

      short, long = if tokens.size <= other.size
                      [tokens, other]
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
  rescue SystemCallError => e
    # A non-writable log dir must not abort an otherwise-successful seed.
    say("Could not write #{path}: #{e.message}")
  end

  def print_summary
    linked = @seeded.count { |r| r[:linked] }
    sub("Seeded column on #{@seeded.size} obs " \
        "(#{linked} linked, #{@seeded.size - linked} free text).")
    sub("Skipped #{@skipped.size} list/junk/user-only variant values.")
    sub("#{@unresolved.size} _user refs unresolved (stored as text).")
  end
end
