# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/backfill_image_dhashes.rb [--scope SCOPE] \
#      [--limit N] [--rehash] [--threads N] [--report-interval SECONDS] \
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
#    The work is network-bound (rendition fetch + API push per image), so
#    it runs on --threads worker threads (default 6; keep below the AR
#    pool size, 10). Serial execution measured ~1 image/s — 6+ days for
#    the full linked corpus.
#
#    Live monitoring: a progress line every --report-interval seconds
#    (default 10) with count, rate, time remaining, completion estimate
#    (dated once it's more than a day out), the latest image id + dhash,
#    and the push counters when pushing.
#
#    --push-url + --push-key-file turn on local-compute/API-push mode
#    (#4585): each hash computed here (on a dev box, sparing the
#    production web server the ImageMagick decode load) is also pushed to
#    the given MO server via PATCH /api2/images set_dhash, over a
#    per-thread persistent connection. The key file holds a site
#    administrator's API key (the endpoint is site-admin-only) — a file,
#    not an argument, so the key stays out of process listings. The
#    server fills only null dhashes; a differing existing value comes
#    back as API2::ImageDhashMismatch, which is logged here and counted
#    as a mismatch — interesting data, never overwritten. Push failures
#    don't abort the run.

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
    @threads = opts[:threads] || 6
    @report_interval = opts[:report_interval] || 10
    parse_push_config(opts)
    @stats = Hash.new(0)
    @mutex = Mutex.new
    @processed = 0
    @started_at = Time.current
  end

  def run
    refresh_table_statistics
    relation = scoped_images
    puts("Computing the #{@scope}-scope image count...")
    total = relation.count
    puts("Backfilling dhashes for #{total} images " \
         "(scope: #{@scope}, threads: #{@threads})")
    process_all(relation, total)
    summarize
  end

  private

  # A freshly-imported database (mysqldump load / checkpoint restore)
  # has stale InnoDB statistics -- auto-recalc is lazy and sampled --
  # and the optimizer then plans the scope semijoin catastrophically
  # (observed: minutes of silent full-scanning). ANALYZE TABLE refreshes
  # the stats in ~1s and is an online, read-safe maintenance statement.
  # NOTE: raw SQL by necessity -- ANALYZE TABLE is maintenance DDL with
  # no ActiveRecord/Arel equivalent; a deliberate, narrow exception to
  # the no-raw-SQL rule (which targets queries).
  def refresh_table_statistics
    puts("Refreshing table statistics (ANALYZE TABLE)...")
    Image.connection.execute(
      "ANALYZE TABLE external_links, observation_images, images"
    )
  end

  def parse_push_config(opts)
    @push_url = opts[:push_url]&.chomp("/")
    @push_key = opts[:push_key_file] && File.read(opts[:push_key_file]).strip
    if @push_url.present? ^ @push_key.present?
      abort("--push-url and --push-key-file must be given together")
    end
    return unless @push_url

    @push_uri = URI("#{@push_url}/api2/images.json")
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

  # Images belonging to observations that have an iNaturalist
  # Observation ExternalLink — the reflection/discovery comparison
  # scope. A pure-SQL subquery chain, deliberately NOT a pluck: the old
  # distinct.pluck materialized ~400k image ids into Ruby and shipped
  # them back as a multi-megabyte IN list on the count AND on every
  # find_each batch, which crawled for minutes on a cold database.
  # Subqueries let MySQL semijoin it all server-side.
  def linked_image_ids
    linked_obs = ExternalLink.
                 where(external_site_id: ExternalSite.inaturalist.id,
                       target_type: "Observation").
                 select(:target_id)
    ObservationImage.where(observation_id: linked_obs).select(:image_id)
  end

  # ------------------------------------------------------------------
  # Threaded pipeline: main thread streams ids into a bounded queue,
  # worker threads hash + push, a reporter thread prints progress.
  # ------------------------------------------------------------------

  def process_all(relation, total)
    queue = SizedQueue.new(@threads * 2)
    workers = start_workers(queue)
    reporter = start_reporter(total)
    relation.select(:id).find_each { |image| queue << image.id }
    queue.close
    workers.each(&:join)
    reporter.kill
    # Final interval-independent report so the progress stream always
    # ends at 100% even when the run finishes between reporter ticks.
    report_progress(total)
  end

  def start_workers(queue)
    Array.new(@threads) do
      Thread.new do
        while (image_id = queue.pop)
          ActiveRecord::Base.connection_pool.with_connection do
            hash_one(Image.find(image_id))
          end
        end
      end
    end
  end

  def start_reporter(total)
    Thread.new do
      loop do
        sleep(@report_interval)
        report_progress(total)
      end
    end
  end

  def hash_one(image)
    image.compute_dhash! if image.dhash.nil? || @rehash
    push_result = @push_url ? push_dhash(image) : nil
    record_result(image, push_result)
  rescue StandardError => e
    @mutex.synchronize do
      @stats[:error] += 1
      @processed += 1
    end
    warn("  image #{image.id}: #{e.class}: #{e.message}")
  end

  def record_result(image, push_result)
    @mutex.synchronize do
      @stats[:hashed] += 1
      @stats[push_result] += 1 if push_result
      @processed += 1
      @last_image_id = image.id
      @last_dhash = image.dhash
    end
    return unless verbose?

    note = push_result ? " (#{push_result})" : ""
    puts("  image #{image.id}: dhash #{image.dhash}#{note}")
  end

  def verbose?
    @limit && @limit <= VERBOSE_LIMIT
  end

  # ------------------------------------------------------------------
  # Push (local-compute/API-push mode)
  # ------------------------------------------------------------------

  # PATCH the freshly computed hash to the remote MO server; returns
  # :pushed, :push_mismatch, or :push_error. The server fills only null
  # dhashes; API2::ImageDhashMismatch means it already holds a DIFFERENT
  # value -- logged and counted, never overwritten. Any push failure is
  # counted and skipped so the hashing run continues; failed pushes can
  # be re-driven later (the endpoint is idempotent for matching values).
  def push_dhash(image)
    classify_push(image, request_push(image))
  rescue StandardError => e
    warn("  image #{image.id}: push failed: #{e.class}: #{e.message}")
    :push_error
  end

  def classify_push(image, error_codes)
    if error_codes.empty?
      :pushed
    elsif error_codes.include?("API2::ImageDhashMismatch")
      warn("  image #{image.id}: DHASH MISMATCH on server " \
           "(local #{image.dhash})")
      :push_mismatch
    else
      warn("  image #{image.id}: push failed: #{error_codes.join(", ")}")
      :push_error
    end
  end

  # Each worker thread keeps one persistent (keep-alive) connection to
  # the push server -- a fresh TLS handshake per image measurably
  # dominated push time. A dropped connection is rebuilt and the
  # request retried once.
  def request_push(image)
    attempts = 0
    begin
      attempts += 1
      request = Net::HTTP::Patch.new(@push_uri.request_uri)
      request.set_form_data(id: image.id, set_dhash: image.dhash,
                            api_key: @push_key)
      parse_push_response(push_http.request(request))
    rescue IOError, Errno::EPIPE, Errno::ECONNRESET
      reset_push_http
      retry if attempts == 1
      raise
    end
  end

  def push_http
    Thread.current[:push_http] ||= Net::HTTP.start(
      @push_uri.host, @push_uri.port,
      use_ssl: @push_uri.scheme == "https",
      open_timeout: 10, read_timeout: 60
    )
  end

  def reset_push_http
    Thread.current[:push_http]&.finish
  rescue IOError
    nil
  ensure
    Thread.current[:push_http] = nil
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

  # ------------------------------------------------------------------
  # Progress reporting
  # ------------------------------------------------------------------

  def report_progress(total)
    done, snapshot, last_id, last_dhash = @mutex.synchronize do
      [@processed, @stats.dup, @last_image_id, @last_dhash]
    end
    return if done.zero?

    warn("  #{pace_report(done, total)}" \
         "#{last_image_report(last_id, last_dhash)}#{push_report(snapshot)}")
  end

  def pace_report(done, total)
    now = Time.current
    elapsed = now - @started_at
    rate = done / [elapsed.to_f, 0.001].max
    left = rate.positive? ? (total - done) / rate : 0
    format("%d/%d (%.1f%%) %.1f/s, ~%s left (ETA %s)",
           done, total, 100.0 * done / [total, 1].max, rate,
           human_duration(left), eta_stamp(now + left, left))
  end

  # Include the date once the estimate is far enough out that a bare
  # time of day would be ambiguous (or misleading by days).
  def eta_stamp(eta, seconds_left)
    eta.strftime(seconds_left >= 20.hours ? "%b %e %H:%M" : "%H:%M:%S")
  end

  def last_image_report(last_id, last_dhash)
    return "" unless last_id

    " -- last: image #{last_id} dhash #{last_dhash}"
  end

  def push_report(snapshot)
    return "" unless @push_url

    " -- pushed #{snapshot[:pushed]}, mismatch #{snapshot[:push_mismatch]}, " \
      "push_err #{snapshot[:push_error]}"
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
    elapsed = human_duration(Time.current - @started_at)
    puts("\nTotals (#{elapsed}): " \
         "#{@stats.sort.map { |k, v| "#{k}: #{v}" }.join(", ")}")
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
  opts.on("--threads N", Integer, "Worker threads (default 6)") do |n|
    options[:threads] = n
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
