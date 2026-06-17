# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/content_match_inat_image_provenance.rb \
#      [-n|--dry-run] [-v|--verbose] [--limit N] [--threshold D]
#
#  DESCRIPTION::
#
#    Content-match fallback for the #4529 backfill. Position inference
#    (infer_inat_image_provenance.rb) skips any observation whose MO
#    imported-image count differs from its current iNat photo count
#    (deletes / re-adds / higher-res swaps). This recovers those by
#    matching on image *content* instead of order: it computes an average
#    hash (aHash) of each MO image and each current iNat photo, then pairs
#    them by smallest Hamming distance (greedy, unique, within --threshold).
#
#    Matched MO images get their iNat photo id written to external_id
#    (with source_id = iNaturalist). Unmatched MO images are real orphans
#    (the iNat photo is gone — overlaps #4543); unmatched iNat photos were
#    added on iNat after import. Both are logged, not guessed.
#
#    Run the parse and position backfills first; this only looks at images
#    still lacking external_id. Hashes are computed by downscaling each
#    image to 8x8 grayscale via ImageMagick, using aspect-preserving sizes
#    on both sides (iNat "medium", MO :small) so the same photo hashes
#    alike. Idempotent, update_columns, -n/--dry-run, --limit N for
#    staging. Reports: content_match_mapped.csv, content_match_unmatched.csv.
#
################################################################################

require("csv")
require("net/http")
require("open3")

# Recovers iNat photo provenance for count-mismatched observations by
# matching MO images to iNat photos on aHash content (#4529).
class InatImageContentMatcher
  BATCH = Inat::ImportAudit::Fetcher::PAGE_SIZE
  CONVERT = ["convert", "-", "-resize", "8x8!", "-colorspace", "Gray",
             "-depth", "8", "gray:-"].freeze
  MAPPED = Rails.root.join("content_match_mapped.csv")
  UNMATCHED = Rails.root.join("content_match_unmatched.csv")

  def initialize(dry_run:, verbose:, limit:, threshold:)
    @dry_run = dry_run
    @verbose = verbose
    @limit = limit
    @threshold = threshold
    @fetcher = Inat::ImportAudit::Fetcher.new
    @source_id = Source.inaturalist.id
    @mapped = []
    @unmatched = []
  end

  def run
    scope = candidates
    log("#{prefix}#{scope.size} observation(s) to content-match " \
        "(threshold #{@threshold})")
    scope.each_slice(BATCH) { |batch| process_batch(batch) }
    write_reports
    summarize
  end

  private

  def candidates
    scope = Observation.where(source_id: @source_id).
            where.not(external_id: [nil, ""]).
            where(id: ObservationImage.joins(:image).
              where(images: { external_id: nil }).
              where("images.notes LIKE ?", "Imported from iNat%").
              select(:observation_id)).order(:id)
    @limit ? scope.limit(@limit) : scope
  end

  def process_batch(observations)
    by_id, = @fetcher.fetch_batch(observations.map(&:external_id))
    observations.each { |obs| process_obs(obs, by_id[obs.external_id.to_s]) }
  end

  def process_obs(obs, raw)
    photos = raw ? hashed_inat_photos(raw) : []
    images = hashed_mo_images(obs)
    return if images.empty?

    matches, unmatched_mo, unmatched_inat = match(images, photos)
    apply(obs, matches)
    log_unmatched(obs, unmatched_mo, unmatched_inat)
    vlog("obs #{obs.id}: matched #{matches.size}, " \
         "orphan MO #{unmatched_mo.size}, extra iNat #{unmatched_inat.size}")
  end

  # [[image, hash], ...] for the observation's imported images lacking
  # external_id, in id order; images that fail to hash are dropped.
  def hashed_mo_images(obs)
    obs.images.where("notes LIKE ?", "Imported from iNat%").
      where(external_id: nil).order(:id).filter_map do |image|
        hash = ahash(download(image.url(:small)))
        [image, hash] if hash
      end
  end

  # [[photo_id, hash], ...] for the current iNat photos (aspect-preserving
  # "medium" so framing matches the MO image, not the cropped "square").
  def hashed_inat_photos(raw)
    (raw[:observation_photos] || []).filter_map do |op|
      url = op.dig(:photo, :url).to_s.sub("square", "medium")
      hash = ahash(download(url))
      [op[:photo_id].to_s, hash] if hash
    end
  end

  # Greedy unique assignment by ascending Hamming distance, within
  # threshold. Returns [matches, unmatched_images, unmatched_photo_ids].
  def match(images, photos)
    matches = greedy_assign(candidate_pairs(images, photos))
    matched_images = matches.map { |image, _pid, _dist| image.id }
    matched_pids = matches.map { |_image, pid, _dist| pid }
    [matches,
     images.map(&:first).reject { |image| matched_images.include?(image.id) },
     photos.map(&:first).reject { |pid| matched_pids.include?(pid) }]
  end

  def candidate_pairs(images, photos)
    images.product(photos).map do |(image, mhash), (pid, ihash)|
      [hamming(mhash, ihash), image, pid]
    end.sort_by(&:first)
  end

  def greedy_assign(pairs)
    used_image = {}
    used_pid = {}
    pairs.each_with_object([]) do |(dist, image, pid), matches|
      next if dist > @threshold || used_image[image.id] || used_pid[pid]

      used_image[image.id] = used_pid[pid] = true
      matches << [image, pid, dist]
    end
  end

  def apply(obs, matches)
    matches.each do |image, pid, dist|
      unless @dry_run
        image.update_columns(source_id: @source_id, external_id: pid)
      end
      @mapped << [image.id, pid, obs.id, dist]
    end
  end

  def log_unmatched(obs, images, pids)
    images.each { |image| @unmatched << [obs.id, "orphan_mo_image", image.id] }
    pids.each { |pid| @unmatched << [obs.id, "extra_inat_photo", pid] }
  end

  def ahash(bytes)
    return nil unless bytes

    out, status = Open3.capture2(
      *CONVERT, stdin_data: bytes, binmode: true, err: File::NULL
    )
    return nil unless status.success? && out.bytesize == 64

    pixels = out.bytes
    avg = pixels.sum.fdiv(64)
    pixels.reduce(0) { |hash, px| (hash << 1) | (px > avg ? 1 : 0) }
  end

  def hamming(left, right)
    (left ^ right).to_s(2).count("1")
  end

  def download(url)
    uri = URI(url)
    res = Net::HTTP.start(uri.host, uri.port,
                          use_ssl: uri.scheme == "https",
                          open_timeout: 10, read_timeout: 20) do |http|
      http.get(uri.request_uri)
    end
    res.is_a?(Net::HTTPSuccess) ? res.body : nil
  rescue StandardError
    nil
  end

  def write_reports
    CSV.open(MAPPED, "w") do |csv|
      csv << %w[image_id external_id observation_id hamming]
      @mapped.each { |row| csv << row }
    end
    CSV.open(UNMATCHED, "w") do |csv|
      csv << %w[observation_id reason ref_id]
      @unmatched.each { |row| csv << row }
    end
    log("Wrote #{MAPPED} and #{UNMATCHED}")
  end

  def summarize
    log("#{prefix}matched #{@mapped.size} image(s)")
    @unmatched.group_by { |row| row[1] }.
      sort_by { |_reason, rows| -rows.size }.
      each { |reason, rows| log("  #{reason}: #{rows.size}") }
  end

  def prefix
    @dry_run ? "[dry-run] " : ""
  end

  def log(msg)
    puts(msg)
  end

  def vlog(msg)
    log(msg) if @verbose
  end
end

def int_arg(name)
  ARGV.each_cons(2).find { |flag, _| flag == name }&.last&.to_i
end

InatImageContentMatcher.new(
  dry_run: ARGV.intersect?(["-n", "--dry-run"]),
  verbose: ARGV.intersect?(["-v", "--verbose"]),
  limit: int_arg("--limit"),
  threshold: int_arg("--threshold") || 10
).run
