# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/backfill_image_dhashes.rb [--scope SCOPE] \
#      [--limit N] [--rehash] [--progress-every N]
#
#  DESCRIPTION::
#
#    Compute Image#dhash (Image::Dhash) for existing MO images that lack one
#    (#4585/#4673). New uploads hash themselves via ImageDhashJob; this
#    backfills the pre-existing corpus.
#
#    --scope controls which images:
#      linked  (default) — images on observations that carry an iNaturalist
#                          Observation ExternalLink. This is the comparison
#                          scope the reflection engine needs; keeps the
#                          backfill small rather than hashing all of MO.
#      all               — every image (a full-corpus backfill).
#
#    Idempotent: images with a dhash are skipped unless --rehash. --limit
#    scopes a trial run. Hashing prefers a local rendition and falls back to
#    fetching the transferred medium image, so it works whether or not the
#    originals are still on this host. An image that fails to hash is logged
#    and skipped.

require "optparse"

class BackfillImageDhashes
  def initialize(opts)
    @scope = opts[:scope] || "linked"
    @limit = opts[:limit]
    @rehash = opts[:rehash]
    @progress_every = opts[:progress_every] || 1000
    @stats = Hash.new(0)
    @started_at = Time.current
  end

  def run
    relation = scoped_images
    total = relation.count
    puts("Backfilling dhashes for #{total} images (scope: #{@scope})")
    relation.find_each.with_index do |image, i|
      hash_one(image)
      progress(i + 1, total) if ((i + 1) % @progress_every).zero?
    end
    summarize
  end

  private

  def scoped_images
    images = base_scope
    images = images.where(dhash: nil) unless @rehash
    images = images.limit(@limit) if @limit
    images
  end

  def base_scope
    return Image.all if @scope == "all"

    Image.where(id: linked_image_ids)
  end

  # Ids of images belonging to observations that have an iNaturalist
  # Observation ExternalLink — the reflection/discovery comparison scope.
  def linked_image_ids
    linked_obs = ExternalLink.
                 where(external_site_id: ExternalSite.inaturalist.id,
                       target_type: "Observation").
                 select(:target_id)
    ObservationImage.where(observation_id: linked_obs).
      distinct.pluck(:image_id)
  end

  def hash_one(image)
    image.compute_dhash!
    @stats[:hashed] += 1
  rescue StandardError => e
    @stats[:error] += 1
    warn("  image #{image.id}: #{e.class}: #{e.message}")
  end

  def progress(done, total)
    elapsed = (Time.current - @started_at).round
    rate = (done / [elapsed, 1].max.to_f).round(1)
    warn("  #{done}/#{total} (#{elapsed}s, #{rate}/s)")
  end

  def summarize
    puts("\nTotals: #{@stats.sort.map { |k, v| "#{k}: #{v}" }.join(", ")}")
  end
end

options = {}
OptionParser.new do |opts|
  opts.on("--scope SCOPE", %w[linked all], "linked (default) or all") do |s|
    options[:scope] = s
  end
  opts.on("--limit N", Integer, "Hash at most N images") do |n|
    options[:limit] = n
  end
  opts.on("--rehash", "Recompute existing hashes") do
    options[:rehash] = true
  end
  opts.on("--progress-every N", Integer, "Progress cadence") do |n|
    options[:progress_every] = n
  end
end.parse!

BackfillImageDhashes.new(options).run
