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
#    Self-hashing: for the sampled observations it fills any missing MO image
#    dHashes (Image#compute_dhash!) and iNat photo dHashes (InatPhotoHash)
#    on the fly, so it does not depend on the full hashing backfills having
#    run — only the extract build. Read-only against iNat/MO otherwise;
#    writes only dHash rows.
#
#    Multi-link MO obs (several iNat links) pick one reflection extract per
#    #4585: the import link if present, else the highest iNat id.

require "csv"
require "optparse"

class InatReflectionReport
  def initialize(opts)
    @limit = opts[:limit] || 200
    @seed = opts[:seed]
    @out = opts[:out] || "inat_reflection_report.csv"
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
    CSV.open(@out, "w") { |csv| write_csv(csv, rows) }
    summarize(rows)
  end

  private

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
    obs = Observation.includes(:images).find(obs_id)
    extract = InatObsExtract.find_by(inat_id: @extract_for[obs_id])
    return nil unless extract

    result = Inat::ReflectionComparator.new(
      mo_obs: obs, extract: extract,
      mo_hashes: mo_hashes(obs), inat_hashes: inat_hashes(extract)
    ).compare
    tally(result)
    row(obs_id, extract, result)
  rescue StandardError => e
    @stats[:error] += 1
    warn("  obs #{obs_id}: #{e.class}: #{e.message}")
    nil
  end

  def mo_hashes(obs)
    obs.images.map { |img| img.dhash || safe_hash { img.compute_dhash! } }
  end

  # Each photo hashes to its four rotation dHashes (downloaded once), so an
  # MO image that is a rotated copy still matches. The single-column
  # InatPhotoHash cache can't hold a rotation set, so these are computed
  # fresh per run (the download — the costly part — happens once either way).
  def inat_hashes(extract)
    Array(extract.photos).map do |photo|
      safe_hash { Image::Dhash.rotations_from_url(photo["url"]) }
    end
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
    [:date, :location, :taxon].each do |f|
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
      taxon_status: result.taxon_status }
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
