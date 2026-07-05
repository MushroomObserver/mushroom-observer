# frozen_string_literal: true

#  USAGE::
#
#    # Compare every MO image on an observation against every photo of its
#    # linked iNat observation(s) — the image-level "is this a clean
#    # reflection?" check (#4585):
#    bin/rails runner script/compare_image_dhashes.rb -- --obs 560938
#
#    # Pairwise distance matrix among specific MO images:
#    bin/rails runner script/compare_image_dhashes.rb -- --images 100,200,300
#
#    # Hash an arbitrary image URL (debugging):
#    bin/rails runner script/compare_image_dhashes.rb -- --url https://...
#
#  DESCRIPTION::
#
#    A manual-inspection helper for the perceptual-hash infrastructure
#    (#4585). Prints Hamming distances (0 = same image, small = near-dup,
#    large = different) alongside the image URLs so you can open the pairs
#    and eyeball them. Read-only: computes hashes on the fly, writes
#    nothing. MO image hashes use the stored `dhash` when present, else are
#    computed live.

require "optparse"

class CompareImageDhashes
  def initialize(opts)
    @opts = opts
  end

  def run
    if @opts[:obs] then compare_obs(@opts[:obs])
    elsif @opts[:images] then compare_mo_images(@opts[:images])
    elsif @opts[:url] then puts("dhash #{Image::Dhash.from_url(@opts[:url])}")
    else warn("Nothing to do — pass --obs, --images, or --url")
    end
  end

  private

  def mo_hash(image)
    image.dhash || image.compute_dhash!
  end

  def d(hash_a, hash_b)
    Image::Dhash.distance(hash_a, hash_b)
  end

  # Compare each MO image on the observation to each photo of its linked
  # iNat observation(s).
  def compare_obs(obs_id)
    obs = Observation.find(obs_id)
    mo_images = obs.images.map { |i| [i, mo_hash(i)] }
    puts("MO obs #{obs_id}: #{mo_images.size} image(s)")

    inat_ids(obs).each do |inat_id|
      photos = inat_photos(inat_id)
      puts("\niNat obs #{inat_id}: #{photos.size} photo(s)")
      photos.each { |photo| compare_photo(photo, mo_images) }
    end
  end

  def compare_photo(photo, mo_images)
    photo_hash = Image::Dhash.from_url(photo["url"])
    puts("  iNat photo #{photo["id"]}  #{photo["url"]}")
    mo_images.each do |image, image_hash|
      puts("    dist #{d(image_hash, photo_hash).to_s.rjust(2)}  " \
           "<- MO image #{image.id}  #{image.original_url}")
    end
  end

  def inat_ids(obs)
    ExternalLink.where(target: obs,
                       external_site_id: ExternalSite.inaturalist.id).
      where.not(external_id: nil).pluck(:external_id)
  end

  # Photos ({id, url}) for an iNat obs — from the cache if present, else a
  # live fetch.
  def inat_photos(inat_id)
    cached = InatObsExtract.find_by(inat_id: inat_id)
    return cached.photos if cached&.photos.present?

    by_id, = Inat::ObsFetcher.new.fetch_batch([inat_id.to_s])
    raw = by_id[inat_id.to_s]
    return [] unless raw

    InatObsExtract.from_raw(raw, fetched_at: Time.current).photos
  end

  def compare_mo_images(ids)
    hashes = mo_hashes_by_id(ids)
    ids.combination(2).each { |a, b| report_pair(a, b, hashes) }
  end

  def mo_hashes_by_id(ids)
    images = Image.where(id: ids).index_by(&:id)
    ids.index_with { |id| images[id] && mo_hash(images[id]) }
  end

  def report_pair(id_a, id_b, hashes)
    return warn("  missing image in pair #{id_a},#{id_b}") unless
      hashes[id_a] && hashes[id_b]

    puts("dist #{d(hashes[id_a], hashes[id_b]).to_s.rjust(2)}  " \
         "MO #{id_a} vs MO #{id_b}")
  end
end

options = {}
OptionParser.new do |opts|
  opts.on("--obs ID", Integer, "MO observation id") { |v| options[:obs] = v }
  opts.on("--images LIST", "Comma-separated MO image ids") do |v|
    options[:images] = v.split(",").map { |s| s.strip.to_i }
  end
  opts.on("--url URL", "Hash a single image URL") { |v| options[:url] = v }
end.parse!

CompareImageDhashes.new(options).run
