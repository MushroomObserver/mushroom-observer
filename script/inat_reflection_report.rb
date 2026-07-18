# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/inat_reflection_report.rb -- \
#      [--limit N] [--seed S] [--out PATH]
#
#  DESCRIPTION::
#
#    First classification report for reflection resolution (#4585). Samples
#    linked MO observations that have a cached iNat extract
#    (build_inat_obs_extracts.rb), runs Inat::ReflectionComparator against
#    each, and writes one CSV row per observation plus a distribution summary
#    to stdout: how many pairs are identical / subset / overlapping /
#    disjoint by images, and how often date / location / taxon differ.
#
#    Hashes come from the pre-computed caches: images.dhash (MO side) and
#    the InatPhotoHash table (iNat side), both backfilled corpus-wide, so
#    the report is a pure DB read + compare with no image downloads. A
#    missing MO hash is computed on the fly as a fallback (rare — a newly
#    added image); a missing iNat hash (un-fetchable private/deleted
#    photo) counts as unmatched. Single-rotation compare only: rotated
#    copies land in the non-match buckets and are reviewed afterward
#    (see inat_hashes). Read-only apart from the rare MO fallback hash.
#
#    Multi-link MO obs (several iNat links) pick one reflection extract per
#    #4585: the import link if present, else the highest iNat id.

require "csv"
require "fileutils"
require "optparse"

class InatReflectionReport
  # Scratch/output for the iNat-sync effort lives under
  # projects/inat-sync/ (git-ignored, via the /projects/ folder), not the
  # repo root or a home directory.
  DEFAULT_OUT = "projects/inat-sync/inat_reflection_report.csv"

  def initialize(opts)
    @limit = opts[:limit] || 200
    @seed = opts[:seed]
    @out = opts[:out] || DEFAULT_OUT
    @stats = Hash.new(0)
    @field = Hash.new(0)
    @started_at = Time.current
  end

  def run
    ids = sample_obs_ids
    puts("Comparing #{ids.length} linked observations (of #{@candidates} " \
         "with cached extracts)")
    rows = ids.each_with_index.filter_map do |id, i|
      warn("  #{i + 1}/#{ids.length}") if ((i + 1) % 25).zero?
      compare_one(id)
    end
    write_report(rows)
    summarize(rows)
  end

  private

  def write_report(rows)
    FileUtils.mkdir_p(File.dirname(@out))
    CSV.open(@out, "w") { |csv| write_csv(csv, rows) }
  end

  def inat_site_id
    @inat_site_id ||= ExternalSite.inaturalist.id
  end

  def obs_links
    ExternalLink.where(external_site_id: inat_site_id,
                       target_type: "Observation").where.not(external_id: nil)
  end

  # Random sample of MO obs ids whose (chosen) iNat link is cached.
  def sample_obs_ids
    cached = InatObsExtract.pluck(:inat_id).to_set
    by_obs = obs_links.pluck(:target_id, :external_id, :relationship).
             group_by(&:first)
    @extract_for = by_obs.filter_map do |obs_id, links|
      chosen = choose_link(links)
      [obs_id, chosen] if chosen && cached.include?(chosen)
    end.to_h
    @candidates = @extract_for.size
    rng = @seed ? Random.new(@seed) : Random.new
    @extract_for.keys.sample(@limit, random: rng)
  end

  # [target_id, external_id, relationship] triples -> chosen iNat id.
  def choose_link(links)
    imported = links.find { |l| l[2] == ExternalLink.relationships[:import] }
    (imported || links.max_by { |l| l[1].to_i })&.at(1)&.to_i
  end

  def compare_one(obs_id)
    obs = Observation.includes(:images, :location, :user, :collector_user).
          find(obs_id)
    extract = InatObsExtract.find_by(inat_id: @extract_for[obs_id])
    return nil unless extract

    result = Inat::ReflectionComparator.new(
      mo_obs: obs, extract: extract,
      mo_hashes: mo_hashes(obs), inat_hashes: inat_hashes(extract),
      mo_context: { box: obs.location, logins: mo_inat_logins(obs) }
    ).compare
    tally(result)
    row(obs_id, extract, result)
  rescue StandardError => e
    @stats[:error] += 1
    warn("  obs #{obs_id}: #{e.class}: #{e.message}")
    nil
  end

  # The MO side's iNat login(s): the owner's, plus the collector's when set.
  def mo_inat_logins(obs)
    [obs.user&.inat_username, obs.collector_user&.inat_username].compact
  end

  def mo_hashes(obs)
    obs.images.map { |img| img.dhash || safe_hash { img.compute_dhash! } }
  end

  # Reads the pre-computed single (rotation-0) hash from the
  # InatPhotoHash cache — the whole corpus is backfilled
  # (script/hash_inat_photos.rb), so the report is a pure DB compare, no
  # re-download. A photo with no cached hash (un-fetchable: private or
  # deleted iNat photos) maps to nil and the comparator counts it
  # unmatched. Rotation-invariant matching is intentionally NOT done
  # here: rotated copies are rare, a rotated pair simply falls into the
  # non-match bucket, and those residuals get a targeted rotation pass
  # after this report (decided 2026-07-18). Image::Dhash.rotations_from_url
  # stays in the model for that later pass.
  def inat_hashes(extract)
    ids = Array(extract.photos).filter_map { |photo| photo["id"] }
    cached = InatPhotoHash.where(inat_photo_id: ids).pluck(:inat_photo_id,
                                                           :dhash).to_h
    ids.map { |id| cached[id] }
  end

  def safe_hash
    yield
  rescue StandardError => e
    @stats[:hash_error] += 1
    warn("    hash failed: #{e.class}: #{e.message}")
    nil
  end

  def tally(result)
    @stats[result.image_relation] += 1
    [:date, :location, :taxon, :collector].each do |f|
      @field[:"#{f}_#{result[:"#{f}_status"]}"] += 1
    end
  end

  def row(obs_id, extract, result)
    { mo_obs_id: obs_id, inat_id: extract.inat_id,
      image_relation: result.image_relation, case_number: result.case_number,
      mo_images: result.mo_image_count, inat_photos: result.inat_photo_count,
      matched: result.matched_image_count, date_status: result.date_status,
      location_status: result.location_status,
      location_meters: result.location_meters,
      mo_coord_source: result.mo_coord_source,
      taxon_status: result.taxon_status,
      collector_status: result.collector_status }
  end

  def write_csv(csv, rows)
    return if rows.empty?

    csv << rows.first.keys
    rows.each { |r| csv << r.values }
  end

  def summarize(rows)
    elapsed = (Time.current - @started_at).round
    puts("\nWrote #{rows.length} rows to #{@out} (#{elapsed}s)")
    print_group("Image relation", relation_counts)
    print_group("Field diffs (match / differ / n-a)", @field.sort)
    puts("\nErrors: #{@stats[:error]}, hash failures: #{@stats[:hash_error]}")
  end

  def relation_counts
    relations = @stats.except(:error, :hash_error)
    relations.sort_by { |_, v| -v }
  end

  def print_group(title, pairs)
    puts("\n#{title}:")
    pairs.each { |k, v| puts("  #{k}: #{v}") }
  end
end

options = {}
OptionParser.new do |opts|
  opts.on("--limit N", Integer, "Sample size (default 200)") do |n|
    options[:limit] = n
  end
  opts.on("--seed S", Integer, "Random seed for the sample") do |s|
    options[:seed] = s
  end
  opts.on("--out PATH", "CSV output path") { |p| options[:out] = p }
end.parse!

InatReflectionReport.new(options).run
