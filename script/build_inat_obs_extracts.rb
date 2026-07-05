# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/build_inat_obs_extracts.rb [--ids 1,2,3] \
#      [--limit N] [--refetch] [--progress-every N]
#
#  DESCRIPTION::
#
#    Populate inat_obs_extracts (#4585) — the compact per-observation cache
#    of comparison-relevant iNat fields the reflection comparator and
#    discovery matching consume. Fetches, in batches of 200 via the shared
#    Inat::ObsFetcher, every iNat observation MO links to (the distinct
#    external_ids of iNaturalist Observation ExternalLinks), and upserts an
#    InatObsExtract per result.
#
#    Idempotent and resumable: by default an id already cached is skipped,
#    so a crashed run just re-runs. --refetch re-fetches everything (e.g.
#    to pick up iNat-side edits). --ids / --limit scope a trial run.
#
#    Read-only against iNat (public GETs); writes only inat_obs_extracts.
#    An id iNat no longer returns (deleted/private) is left uncached and
#    logged; a batch that fails all its retries is logged and skipped so a
#    transient outage doesn't abort the whole run.

require "optparse"

class BuildInatObsExtracts
  BATCH_SIZE = Inat::ObsFetcher::PAGE_SIZE

  def initialize(opts)
    @only_ids = opts[:ids]
    @limit = opts[:limit]
    @refetch = opts[:refetch]
    @progress_every = opts[:progress_every] || 1000
    @fetcher = Inat::ObsFetcher.new
    @stats = Hash.new(0)
    @started_at = Time.current
  end

  def run
    ids = target_ids
    puts("Building extracts for #{ids.length} iNat ids " \
         "(batch #{BATCH_SIZE})")
    ids.each_slice(BATCH_SIZE).with_index do |batch, i|
      process_batch(batch)
      sleep(Inat::ObsFetcher::INTER_PAGE_SLEEP)
      progress(i) if ((i + 1) % (@progress_every / BATCH_SIZE).ceil).zero?
    end
    summarize
  end

  private

  def target_ids
    ids = linked_inat_ids
    ids &= @only_ids if @only_ids
    ids -= already_cached_ids(ids) unless @refetch
    ids = ids.first(@limit) if @limit
    ids
  end

  # Distinct external_ids of iNaturalist Observation links (the MO↔iNat
  # correspondences materialized by #4565).
  def linked_inat_ids
    ExternalLink.where(external_site_id: ExternalSite.inaturalist.id,
                       target_type: "Observation").
      where.not(external_id: nil).
      distinct.pluck(:external_id).map(&:to_i).sort
  end

  def already_cached_ids(ids)
    InatObsExtract.where(inat_id: ids).pluck(:inat_id)
  end

  def process_batch(batch)
    by_id, failed = @fetcher.fetch_batch(batch.map(&:to_s))
    if failed
      @stats[:fetch_failed] += batch.size
      warn("  batch of #{batch.size} failed after retries; skipped")
      return
    end
    fetched_at = Time.current
    batch.each { |id| record_one(by_id[id.to_s], fetched_at) }
  end

  def record_one(raw, fetched_at)
    return @stats[:not_found] += 1 unless raw

    InatObsExtract.upsert_from_raw(raw, fetched_at: fetched_at)
    @stats[:cached] += 1
  rescue StandardError => e
    @stats[:error] += 1
    warn("  iNat #{raw[:id]}: #{e.class}: #{e.message}")
  end

  def progress(batch_index)
    done = (batch_index + 1) * BATCH_SIZE
    elapsed = (Time.current - @started_at).round
    rate = (done / [elapsed, 1].max.to_f).round(1)
    warn("  ~#{done} processed (#{elapsed}s, #{rate}/s)")
  end

  def summarize
    puts("\nTotals: #{@stats.sort.map { |k, v| "#{k}: #{v}" }.join(", ")}")
  end
end

options = {}
OptionParser.new do |opts|
  opts.on("--ids LIST", "Only these iNat obs ids") do |list|
    options[:ids] = list.split(",").map { |s| s.strip.to_i }
  end
  opts.on("--limit N", Integer, "Process at most N ids") do |n|
    options[:limit] = n
  end
  opts.on("--refetch", "Re-fetch ids already cached") do
    options[:refetch] = true
  end
  opts.on("--progress-every N", Integer, "Progress cadence") do |n|
    options[:progress_every] = n
  end
end.parse!

BuildInatObsExtracts.new(options).run
