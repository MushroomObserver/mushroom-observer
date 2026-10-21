# frozen_string_literal: true

# Add-only DNA-sequence backfill from iNat: creates the Sequences an
# iNat-linked MO observation lacks, from (inat_id, mo_observation_id)
# pairs in a CSV (#4215).
#
#   bin/rails runner script/backfill_inat_sequences.rb \
#     -- --csv projects/inat-dna-no-mo-sequence.csv [--limit N] [--apply]
#
# --touch-feed restores the normal activity-feed bump, suppressed by
# default so a bulk run does not take the feed over.

# Nothing is updated or deleted: most targets are community
# observations rather than reflections, so an existing MO sequence is
# user data. Matching on Sequence#bases_nucleotides makes a re-run,
# and the resync engine later, skip what this added.

# A pair is written only when the MO observation has an ExternalLink
# to that iNat id: iNat's Mushroom Observer URL field can point at the
# wrong observation, and a sequence must not land on a mismatched
# record. Mismatches are reported rather than written.

require("optparse")
require("csv")

class BackfillInatSequences
  # The Sequence create callback hardcodes touch: true; for this bulk
  # run the entry is still logged, without jumping the observation to
  # the top of the activity feed.
  module QuietSequenceAddLog
    def log_add_sequence
      observation.log(:log_sequence_added, user: user,
                                           name: "Sequence ##{id}",
                                           touch: false)
    end
  end

  BATCH = 200
  PAGE_SLEEP = 1.0
  PROGRESS_EVERY = 5 # batches

  USAGE = "Usage: ... -- --csv PATH [--apply] [--limit N] [--touch-feed]"

  def initialize(argv)
    @apply = false
    @csv = nil
    @limit = 0
    @touch_feed = false
    parse_argv(argv)
    @tallies = Hash.new(0)
    @added = 0
    @started = Time.zone.now
  end

  def run
    Sequence.prepend(QuietSequenceAddLog) unless @touch_feed
    rows = load_rows
    warn("processing #{rows.size} pairs#{" (dry run)" unless @apply}")
    rows.each_slice(BATCH).with_index do |slice, i|
      sleep(PAGE_SLEEP) if i.positive?
      process_batch(slice)
      progress(i + 1, rows.size)
    end
    summary
  end

  private

  def parse_argv(argv)
    OptionParser.new do |op|
      op.banner = USAGE
      op.on("--csv PATH", String) { |p| @csv = p }
      op.on("--apply") { @apply = true }
      op.on("--limit N", Integer) { |n| @limit = n }
      op.on("--touch-feed") { @touch_feed = true }
    end.parse!(argv)
    abort("--csv PATH is required\n#{USAGE}") if @csv.blank?
    abort("#{@csv} not found") unless File.exist?(@csv)
  rescue OptionParser::ParseError => e
    abort("#{e.message}\n#{USAGE}")
  end

  def load_rows
    rows = CSV.read(@csv, headers: true).map do |row|
      [row["inat_id"].to_s, row["mo_observation_id"].to_i]
    end
    @limit.positive? ? rows.first(@limit) : rows
  end

  def process_batch(slice)
    by_id, failed = Inat::ObsFetcher.new.fetch_batch(slice.map(&:first))
    if failed
      # slice is an Array of [inat_id, mo_id] pairs, not a Hash.
      slice.each { |pair| tally(:fetch_failed, pair.first) }
      return
    end
    slice.each do |inat_id, mo_id|
      process_pair(inat_id, mo_id, by_id[inat_id])
    end
  end

  def process_pair(inat_id, mo_id, raw)
    return tally(:inat_missing, inat_id) unless raw

    obs = Observation.find_by(id: mo_id)
    return tally(:obs_missing, mo_id) unless obs
    return tally(:link_mismatch, mo_id) unless linked?(obs, inat_id)

    desired = Inat::Obs.new(JSON.generate(raw)).sequences
    return tally(:no_detectable_sequence, mo_id) if desired.empty?

    add_missing(obs, desired)
  end

  # ExternalLink to this iNat id, any relationship -- import, mirror,
  # copy or manual all establish the correspondence.
  def linked?(obs, inat_id)
    obs.external_links.any? do |link|
      link.external_site&.name == ExternalSite::INATURALIST_NAME &&
        link.external_id.to_s == inat_id
    end
  end

  def add_missing(obs, desired)
    existing = obs.sequences.map(&:bases_nucleotides)
    added_here = 0
    desired.each do |d|
      norm = normalize(d[:bases])
      next if existing.include?(norm)

      next tally(:invalid, obs.id) unless create_sequence(obs, d)

      existing << norm
      added_here += 1
    end
    record_outcome(obs, added_here)
  end

  def record_outcome(obs, added_here)
    if added_here.positive?
      @added += added_here
      tally(:obs_gained_sequences, obs.id)
      warn("ADDED #{added_here} to obs #{obs.id}") if @apply
    else
      tally(:already_covered, obs.id)
    end
  end

  def create_sequence(obs, desired)
    return true unless @apply # dry run counts it as addable

    obs.sequences.create!(
      user: obs.user,
      locus: desired[:locus],
      bases: desired[:bases],
      archive: desired[:archive],
      accession: desired[:accession].to_s,
      notes: desired[:notes].to_s
    )
    true
  rescue ActiveRecord::RecordInvalid => e
    warn("INVALID obs #{obs.id} (locus #{desired[:locus].inspect}): " \
         "#{e.message}")
    false
  end

  # Sequence#bases_nucleotides for a raw iNat value.
  def normalize(bases)
    bases.to_s.sub(Sequence::DESCRIPTION, "").gsub(/[\d\s]/, "")
  end

  def tally(key, id)
    @tallies[key] += 1
    return unless [:link_mismatch, :obs_missing, :inat_missing].include?(key)

    warn("#{key.upcase} #{id}")
  end

  def progress(batch, total_rows)
    return unless (batch % PROGRESS_EVERY).zero?

    elapsed = (Time.zone.now - @started).round
    done = [batch * BATCH, total_rows].min
    warn("[#{elapsed}s] #{done}/#{total_rows} pairs, " \
         "sequences #{@apply ? "added" : "addable"}: #{@added}")
  end

  def summary
    verb = @apply ? "added" : "would add"
    warn("Done. sequences #{verb}: #{@added}")
    @tallies.sort_by { |_k, v| -v }.each { |k, v| warn("  #{k}: #{v}") }
    return if @apply

    warn("Dry run - nothing written. To apply: bin/rails runner " \
         "script/backfill_inat_sequences.rb -- --csv #{@csv} " \
         "--apply")
  end
end

BackfillInatSequences.new(ARGV).run
