# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/hash_inat_photos.rb [--limit N] [--rehash] \
#      [--progress-every N]
#
#  DESCRIPTION::
#
#    Compute a perceptual hash (Image::Dhash) for each iNat photo referenced
#    by a cached extract (#4585), storing it in inat_photo_hashes keyed by
#    the iNat photo id. These are the hashes the reflection comparator
#    matches MO image dhashes against to decide image identity across
#    resolution differences.
#
#    Fetches each photo's medium rendition (the url cached in
#    inat_obs_extracts.photos) and hashes it. Idempotent: a photo id already
#    hashed is skipped unless --rehash. --limit scopes a trial run. A photo
#    that fails to fetch/decode is logged and skipped so one bad url doesn't
#    abort the run.
#
#    Depends on build_inat_obs_extracts.rb having populated the extracts.
#    Courtesy-paced with a short sleep between fetches.

require "optparse"

class HashInatPhotos
  SLEEP_BETWEEN = 0.3

  def initialize(opts)
    @limit = opts[:limit]
    @rehash = opts[:rehash]
    @progress_every = opts[:progress_every] || 500
    @stats = Hash.new(0)
    @started_at = Time.current
  end

  def run
    photos = target_photos
    puts("Hashing #{photos.length} iNat photos")
    photos.each_with_index do |photo, i|
      hash_one(photo)
      progress(i + 1) if ((i + 1) % @progress_every).zero?
    end
    summarize
  end

  private

  # Distinct { id, url } photos across all cached extracts, minus those
  # already hashed (unless --rehash).
  def target_photos
    photos = distinct_photos
    photos.reject! { |p| already_hashed.include?(p["id"]) } unless @rehash
    photos = photos.first(@limit) if @limit
    photos
  end

  def distinct_photos
    seen = Set.new
    acc = []
    InatObsExtract.where.not(photos: nil).find_each do |ext|
      Array(ext.photos).each do |photo|
        next if photo["id"].blank? || photo["url"].blank?

        acc << photo if seen.add?(photo["id"])
      end
    end
    acc
  end

  def already_hashed
    @already_hashed ||= InatPhotoHash.pluck(:inat_photo_id).to_set
  end

  def hash_one(photo)
    dhash = Image::Dhash.from_url(photo["url"])
    record = InatPhotoHash.find_or_initialize_by(inat_photo_id: photo["id"])
    record.update!(dhash: dhash, fetched_at: Time.current)
    @stats[:hashed] += 1
    sleep(SLEEP_BETWEEN)
  rescue StandardError => e
    @stats[:error] += 1
    warn("  photo #{photo["id"]}: #{e.class}: #{e.message}")
  end

  def progress(done)
    elapsed = (Time.current - @started_at).round
    rate = (done / [elapsed, 1].max.to_f).round(1)
    warn("  #{done} hashed (#{elapsed}s, #{rate}/s)")
  end

  def summarize
    puts("\nTotals: #{@stats.sort.map { |k, v| "#{k}: #{v}" }.join(", ")}")
  end
end

options = {}
OptionParser.new do |opts|
  opts.on("--limit N", Integer, "Hash at most N photos") do |n|
    options[:limit] = n
  end
  opts.on("--rehash", "Recompute hashes already stored") do
    options[:rehash] = true
  end
  opts.on("--progress-every N", Integer, "Progress cadence") do |n|
    options[:progress_every] = n
  end
end.parse!

HashInatPhotos.new(options).run
