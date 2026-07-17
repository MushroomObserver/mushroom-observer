# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/hash_inat_photos.rb [--limit N] [--rehash] \
#      [--threads N] [--report-interval SECONDS]
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
#    hashed is skipped unless --rehash. --limit scopes a trial run; small
#    trial runs (--limit <= 25) print each photo's id + hash. A photo
#    that fails to fetch/decode is logged and skipped so one bad url
#    doesn't abort the run.
#
#    Depends on build_inat_obs_extracts.rb having populated the extracts.
#    Runs on --threads workers (default 4), each courtesy-paced with a
#    short sleep between fetches -- aggregate load on iNat's CDN stays
#    around threads/0.3 ≈ 13 req/s at the default. Live monitoring every
#    --report-interval seconds (default 10) with rate and a dated
#    completion estimate.

require "optparse"

class HashInatPhotos
  SLEEP_BETWEEN = 0.3
  VERBOSE_LIMIT = 25

  def initialize(opts)
    @limit = opts[:limit]
    @rehash = opts[:rehash]
    @threads = opts[:threads] || 4
    @report_interval = opts[:report_interval] || 10
    @stats = Hash.new(0)
    @mutex = Mutex.new
    @processed = 0
    @started_at = Time.current
  end

  def run
    photos = target_photos
    puts("Hashing #{photos.length} iNat photos (threads: #{@threads})")
    process_all(photos)
    puts("\nTotals (#{human_duration(Time.current - @started_at)}): " \
         "#{@stats.sort.map { |k, v| "#{k}: #{v}" }.join(", ")}")
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

  def process_all(photos)
    queue = SizedQueue.new(@threads * 2)
    workers = start_workers(queue)
    reporter = start_reporter(photos.length)
    photos.each { |photo| queue << photo }
    queue.close
    workers.each(&:join)
    reporter.kill
    # Final interval-independent report so the progress stream always
    # ends at 100% even when the run finishes between reporter ticks.
    report_progress(photos.length)
  end

  def start_workers(queue)
    Array.new(@threads) do
      Thread.new do
        while (photo = queue.pop)
          ActiveRecord::Base.connection_pool.with_connection do
            hash_one(photo)
          end
          sleep(SLEEP_BETWEEN)
        end
      end
    end
  end

  def hash_one(photo)
    dhash = Image::Dhash.from_url(photo["url"])
    record = InatPhotoHash.find_or_initialize_by(inat_photo_id: photo["id"])
    record.update!(dhash: dhash, fetched_at: Time.current)
    record_result(photo, dhash)
  rescue StandardError => e
    @mutex.synchronize do
      @stats[:error] += 1
      @processed += 1
    end
    warn("  photo #{photo["id"]}: #{e.class}: #{e.message}")
  end

  def record_result(photo, dhash)
    @mutex.synchronize do
      @stats[:hashed] += 1
      @processed += 1
      @last_photo_id = photo["id"]
      @last_dhash = dhash
    end
    puts("  photo #{photo["id"]}: dhash #{dhash}") if verbose?
  end

  def verbose?
    @limit && @limit <= VERBOSE_LIMIT
  end

  def start_reporter(total)
    Thread.new do
      loop do
        sleep(@report_interval)
        report_progress(total)
      end
    end
  end

  def report_progress(total)
    done, last_id, last_dhash = @mutex.synchronize do
      [@processed, @last_photo_id, @last_dhash]
    end
    return if done.zero?

    warn("  #{pace_report(done, total)} " \
         "-- last: photo #{last_id} dhash #{last_dhash}")
  end

  def pace_report(done, total)
    now = Time.current
    rate = done / [(now - @started_at).to_f, 0.001].max
    left = rate.positive? ? (total - done) / rate : 0
    format("%d/%d (%.1f%%) %.1f/s, ~%s left (ETA %s)",
           done, total, 100.0 * done / [total, 1].max, rate,
           human_duration(left), eta_stamp(now + left, left))
  end

  def eta_stamp(eta, seconds_left)
    eta.strftime(seconds_left >= 20.hours ? "%b %e %H:%M" : "%H:%M:%S")
  end

  def human_duration(seconds)
    seconds = seconds.round
    if seconds >= 3600
      format("%dh %02dm", seconds / 3600, (seconds % 3600) / 60)
    elsif seconds >= 60
      format("%dm %02ds", seconds / 60, seconds % 60)
    else
      "#{seconds}s"
    end
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
  opts.on("--threads N", Integer, "Worker threads (default 4)") do |n|
    options[:threads] = n
  end
  opts.on("--report-interval N", Integer,
          "Seconds between progress reports (default 10)") do |n|
    options[:report_interval] = n
  end
end.parse!

HashInatPhotos.new(options).run
