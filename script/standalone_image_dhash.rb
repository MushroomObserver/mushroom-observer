# frozen_string_literal: true

#  USAGE (on the images server -- plain Ruby + ImageMagick, no Rails)::
#
#    ruby standalone_image_dhash.rb --dir /data/images/mo/320 \
#      --out dhashes.csv [--ids-file ids.txt] [--threads N] \
#      [--report-interval SECONDS]
#
#  DESCRIPTION::
#
#    Standalone half of the #4585 dhash backfill: computes the 64-bit
#    dHash for every <id>.jpg rendition in --dir, writing "id,dhash" CSV
#    rows to --out. Runs where the files live (the images server), so no
#    image bytes cross the network at all; the CSV then feeds
#    script/transfer_image_dhashes.rb --apply on the web server.
#
#    MUST MATCH Image::Dhash (app/models/image/dhash.rb) BIT-FOR-BIT --
#    the convert invocation and bit packing below are copied from it
#    verbatim; if that class changes, change this to match. Verify after
#    any change (and once per ImageMagick version -- IM6 here vs IM7
#    elsewhere) by applying a slice that overlaps already-hashed images
#    and checking the apply script reports already_set, not mismatch.
#
#    --ids-file restricts to listed image ids (one per line); default is
#    every <id>.jpg in --dir (the full corpus also serves #4673
#    duplicate detection). Resumable: ids already present in --out are
#    skipped, so a crashed run just re-runs. --threads (default 4)
#    parallelizes the convert shell-outs; keep it modest -- this box's
#    day job is serving images.

# Standalone: plain Ruby, no ActiveSupport -- Time.zone does not exist
# here, and Rails-flavored cops must not "fix" it back in.
require "optparse"
require "open3"
require "csv"

class StandaloneImageDhash
  WIDTH = 9
  HEIGHT = 8

  def initialize(opts)
    @dir = opts[:dir] || abort("--dir is required")
    @out = opts[:out] || abort("--out is required")
    @ids_file = opts[:ids_file]
    @threads = opts[:threads] || 4
    @report_interval = opts[:report_interval] || 10
    @mutex = Mutex.new
    @stats = Hash.new(0)
    @processed = 0
    @started_at = Time.now
  end

  def run
    ids = target_ids
    puts("Hashing #{ids.length} renditions from #{@dir} " \
         "(threads: #{@threads}, out: #{@out})")
    process_all(ids)
    puts("\nTotals (#{human_duration(Time.now - @started_at)}): " \
         "#{@stats.sort.map { |k, v| "#{k}: #{v}" }.join(", ")}")
  end

  private

  def target_ids
    ids = @ids_file ? File.readlines(@ids_file).map(&:to_i) : dir_ids
    done = already_done
    ids.reject { |id| done.include?(id) }
  end

  def dir_ids
    Dir.entries(@dir).filter_map do |name|
      id = name[/\A(\d+)\.jpg\z/, 1]
      id&.to_i
    end.sort
  end

  # Resumability: skip ids already recorded in a previous (partial) run.
  def already_done
    return Set.new unless File.exist?(@out)

    CSV.foreach(@out, headers: true).to_set { |row| row["id"].to_i }
  end

  def process_all(ids)
    csv = CSV.open(@out, "a")
    csv << %w[id dhash] if File.empty?(@out)
    queue = SizedQueue.new(@threads * 2)
    workers = start_workers(queue, csv)
    reporter = start_reporter(ids.length)
    ids.each { |id| queue << id }
    queue.close
    workers.each(&:join)
    reporter.kill
    csv.close
  end

  def start_workers(queue, csv)
    Array.new(@threads) do
      Thread.new do
        while (id = queue.pop)
          hash_one(id, csv)
        end
      end
    end
  end

  def hash_one(id, csv)
    dhash = from_file(File.join(@dir, "#{id}.jpg"))
    @mutex.synchronize do
      csv << [id, dhash]
      @stats[:hashed] += 1
      @processed += 1
      @last_id = id
      @last_dhash = dhash
    end
  rescue StandardError => e
    @mutex.synchronize do
      @stats[:error] += 1
      @processed += 1
    end
    warn("  image #{id}: #{e.class}: #{e.message}")
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
      [@processed, @last_id, @last_dhash]
    end
    return if done.zero?

    warn("  #{pace_report(done, total)} " \
         "-- last: image #{last_id} dhash #{last_dhash}")
  end

  def pace_report(done, total)
    now = Time.now
    rate = done / [(now - @started_at).to_f, 0.001].max
    left = rate.positive? ? (total - done) / rate : 0
    format("%d/%d (%.1f%%) %.1f/s, ~%s left (ETA %s)",
           done, total, 100.0 * done / [total, 1].max, rate,
           human_duration(left), eta_stamp(now + left, left))
  end

  def eta_stamp(eta, seconds_left)
    eta.strftime(seconds_left >= 20 * 3600 ? "%b %e %H:%M" : "%H:%M:%S")
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

  # ------------------------------------------------------------------
  # The algorithm -- copied verbatim from Image::Dhash; keep in sync.
  # ------------------------------------------------------------------

  def from_file(path)
    bits_from(grayscale_pixels(path))
  end

  # Each bit records whether a pixel is brighter than its right-hand
  # neighbor, row by row: 8 rows x 8 comparisons = 64 bits.
  def bits_from(pixels)
    hash = 0
    HEIGHT.times do |row|
      (WIDTH - 1).times do |col|
        left = pixels[(row * WIDTH) + col]
        right = pixels[(row * WIDTH) + col + 1]
        hash = (hash << 1) | (left > right ? 1 : 0)
      end
    end
    hash
  end

  def grayscale_pixels(path)
    out, err, status = Open3.capture3(
      "convert", "#{path}[0]", "-auto-orient", "-colorspace", "Gray",
      "-resize", "#{WIDTH}x#{HEIGHT}!", "-depth", "8", "gray:-"
    )
    unless status.success? && out.bytesize == WIDTH * HEIGHT
      raise("ImageMagick failed for #{path} " \
            "(status #{status.exitstatus}): #{err.strip}")
    end

    out.bytes
  end
end

options = {}
OptionParser.new do |opts|
  opts.on("--dir DIR", "Directory of <id>.jpg renditions") do |d|
    options[:dir] = d
  end
  opts.on("--out FILE", "CSV output (appended; resumable)") do |f|
    options[:out] = f
  end
  opts.on("--ids-file FILE", "Only hash these image ids (one per line)") do |f|
    options[:ids_file] = f
  end
  opts.on("--threads N", Integer, "Worker threads (default 4)") do |n|
    options[:threads] = n
  end
  opts.on("--report-interval N", Integer,
          "Seconds between progress reports (default 10)") do |n|
    options[:report_interval] = n
  end
end.parse!

StandaloneImageDhash.new(options).run
