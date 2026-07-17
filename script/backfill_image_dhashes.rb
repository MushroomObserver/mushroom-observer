# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/backfill_image_dhashes.rb [--scope SCOPE] \
#      [--limit N] [--rehash] [--report-interval SECONDS] \
#      [--push-url URL --push-key-file PATH]
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
#    scopes a trial run; small trial runs (--limit <= 25) print each
#    image's id + computed dhash (and its push outcome, in push mode) so
#    the 1-then-10-then-all ramp can be eyeballed. Hashing prefers a local
#    rendition and falls back to fetching the transferred medium image, so
#    it works whether or not the originals are still on this host. An
#    image that fails to hash is logged and skipped.
#
#    Live monitoring: a progress line every --report-interval seconds
#    (default 10) with count, rate, time remaining, wall-clock completion
#    estimate (both from the run's own average rate so far), the latest
#    image id + dhash, and the push counters when pushing.
#
#    --push-url + --push-key-file turn on local-compute/API-push mode
#    (#4585): each hash computed here (on a dev box, sparing the
#    production web server the ImageMagick decode load) is also pushed to
#    the given MO server via PATCH /api2/images set_dhash. The key file
#    holds a site administrator's API key (the endpoint is
#    site-admin-only) — a file, not an argument, so the key stays out of
#    process listings. The server fills only null dhashes; a differing
#    existing value comes back as API2::ImageDhashMismatch, which is
#    logged here and counted as a mismatch — interesting data, never
#    overwritten. Push failures don't abort the run.

require "optparse"
require "net/http"
require "json"

class BackfillImageDhashes
  # --limit at or below this prints one line per image (id, dhash, push
  # outcome) -- sized for the check-1-then-10 ramp-up runs.
  VERBOSE_LIMIT = 25

  def initialize(opts)
    @scope = opts[:scope] || "linked"
    @limit = opts[:limit]
    @rehash = opts[:rehash]
    @report_interval = opts[:report_interval] || 10
    parse_push_config(opts)
    @stats = Hash.new(0)
    @started_at = Time.current
    @last_report_at = @started_at
  end

  def run
    relation = scoped_images
    total = relation.count
    puts("Backfilling dhashes for #{total} images (scope: #{@scope})")
    relation.find_each.with_index do |image, i|
      hash_one(image)
      report_progress(i + 1, total)
    end
    summarize
  end

  private

  def parse_push_config(opts)
    @push_url = opts[:push_url]&.chomp("/")
    @push_key = opts[:push_key_file] && File.read(opts[:push_key_file]).strip
    return unless @push_url.present? ^ @push_key.present?

    abort("--push-url and --push-key-file must be given together")
  end

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
    @last_image = image
    push_dhash(image) if @push_url
    log_verbose(image) if verbose?
  rescue StandardError => e
    @stats[:error] += 1
    warn("  image #{image.id}: #{e.class}: #{e.message}")
  end

  def verbose?
    @limit && @limit <= VERBOSE_LIMIT
  end

  def log_verbose(image)
    note = @push_url ? " (#{@last_push})" : ""
    puts("  image #{image.id}: dhash #{image.dhash}#{note}")
  end

  # PATCH the freshly computed hash to the remote MO server. The server
  # fills only null dhashes; API2::ImageDhashMismatch means it already
  # holds a DIFFERENT value -- logged and counted, never overwritten.
  # Any push failure is counted and skipped so the local hashing run
  # continues; failed pushes can be re-driven later (the endpoint is
  # idempotent for matching values).
  def push_dhash(image)
    classify_push(image, request_push(image))
  rescue StandardError => e
    @last_push = :push_error
    @stats[:push_error] += 1
    warn("  image #{image.id}: push failed: #{e.class}: #{e.message}")
  end

  def classify_push(image, error_codes)
    if error_codes.empty?
      @last_push = :pushed
      @stats[:pushed] += 1
    elsif error_codes.include?("API2::ImageDhashMismatch")
      @last_push = :mismatch
      @stats[:push_mismatch] += 1
      warn("  image #{image.id}: DHASH MISMATCH on server " \
           "(local #{image.dhash})")
    else
      @last_push = :push_error
      @stats[:push_error] += 1
      warn("  image #{image.id}: push failed: #{error_codes.join(", ")}")
    end
  end

  # Returns the API2 error codes from the response ([] on success).
  # Timeouts keep one stalled connection from hanging the whole run.
  def request_push(image)
    uri = URI("#{@push_url}/api2/images.json")
    request = Net::HTTP::Patch.new(uri)
    request.set_form_data(id: image.id, set_dhash: image.dhash,
                          api_key: @push_key)
    response = Net::HTTP.start(uri.host, uri.port,
                               use_ssl: uri.scheme == "https",
                               open_timeout: 10, read_timeout: 60) do |http|
      http.request(request)
    end
    parse_push_response(response)
  end

  # API2 reports its own errors as JSON in a 200 response; a non-2xx
  # never reached the normal API flow (proxy error, 500, wrong path)
  # and its body may not be JSON at all -- report the status instead
  # of a confusing JSON parse error.
  def parse_push_response(response)
    return ["HTTP #{response.code}"] unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    (body["errors"] || []).pluck("code")
  end

  # Time-based progress: a line every @report_interval seconds with
  # rate, remaining-time and wall-clock completion estimates (from the
  # run's own average rate), the latest image processed, and the push
  # counters in push mode.
  def report_progress(done, total)
    now = Time.current
    return if now - @last_report_at < @report_interval

    @last_report_at = now
    warn("  #{pace_report(done, total, now)}#{last_image_report}" \
         "#{push_report}")
  end

  def pace_report(done, total, now)
    elapsed = now - @started_at
    rate = done / [elapsed.to_f, 0.001].max
    left = rate.positive? ? (total - done) / rate : 0
    format("%d/%d (%.1f%%) %.1f/s, ~%s left (ETA %s)",
           done, total, 100.0 * done / [total, 1].max, rate,
           human_duration(left), (now + left).strftime("%H:%M:%S"))
  end

  def last_image_report
    return "" unless @last_image

    " -- last: image #{@last_image.id} dhash #{@last_image.dhash}"
  end

  def push_report
    return "" unless @push_url

    " -- pushed #{@stats[:pushed]}, mismatch #{@stats[:push_mismatch]}, " \
      "push_err #{@stats[:push_error]}"
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
  opts.on("--report-interval N", Integer,
          "Seconds between progress reports (default 10)") do |n|
    options[:report_interval] = n
  end
  opts.on("--push-url URL", "Push hashes to this MO server via API2") do |u|
    options[:push_url] = u
  end
  opts.on("--push-key-file PATH",
          "File holding a site admin API key for --push-url") do |p|
    options[:push_key_file] = p
  end
end.parse!

BackfillImageDhashes.new(options).run
