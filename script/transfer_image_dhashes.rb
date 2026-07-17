# frozen_string_literal: true

#  USAGE::
#
#    # Phase 1 (dev box): hash locally with backfill_image_dhashes.rb
#    # (no --push-url), then export the results:
#    bin/rails runner script/transfer_image_dhashes.rb --export dhashes.csv
#
#    # Transfer dhashes.csv to the production server, then apply there:
#    bin/rails runner script/transfer_image_dhashes.rb --apply dhashes.csv \
#      [--limit N] [--report-interval SECONDS]
#
#  DESCRIPTION::
#
#    Backend-load half of the #4585 dhash backfill: hashing runs on a dev
#    box (see backfill_image_dhashes.rb), and the results move to
#    production as a CSV + database load instead of 544k API calls --
#    the production web tier rate-limits API traffic to ~1 req/s per
#    client, which made the API-push path a 6-day run.
#
#    --export writes "id,dhash" for every locally hashed image.
#
#    --apply reads that CSV and applies it with the same semantics as
#    the API2 set_dhash endpoint (#4831):
#      - fill-NULL-only, enforced atomically IN the UPDATE
#        (`WHERE dhash IS NULL`), so it cannot race ImageDhashJob
#        hashing a fresh upload;
#      - never touches updated_at (dhash is derived data; bumping it
#        would flip the #4808 cache-busting URL token);
#      - an existing equal value counts as already_set; a DIFFERENT
#        existing value is counted + logged as a mismatch, never
#        overwritten; a missing image id is counted + logged.
#    Idempotent and resumable: re-running the same CSV is harmless.
#    --limit applies only the first N rows (the 1-then-10 ramp);
#    limits <= 25 log each row's outcome.

require "optparse"
require "csv"

class TransferImageDhashes
  VERBOSE_LIMIT = 25

  def initialize(opts)
    @export = opts[:export]
    @apply = opts[:apply]
    @limit = opts[:limit]
    @report_interval = opts[:report_interval] || 10
    abort("Give exactly one of --export FILE or --apply FILE") unless
      @export.nil? ^ @apply.nil?
    @stats = Hash.new(0)
    @started_at = Time.current
    @last_report_at = @started_at
  end

  def run
    @export ? run_export : run_apply
  end

  private

  def run_export
    count = 0
    CSV.open(@export, "w") do |csv|
      csv << %w[id dhash]
      Image.where.not(dhash: nil).select(:id, :dhash).find_each do |image|
        csv << [image.id, image.dhash]
        count += 1
      end
    end
    puts("Exported #{count} image dhashes to #{@export}")
  end

  def run_apply
    rows = load_rows
    total = rows.length
    puts("Applying #{total} dhashes (fill-NULL-only)...")
    rows.each_with_index do |(id, dhash), i|
      apply_one(id, dhash)
      report_progress(i + 1, total)
    end
    summarize
  end

  def load_rows
    rows = CSV.read(@apply, headers: true).map do |row|
      [row["id"].to_i, row["dhash"].to_i]
    end
    @limit ? rows.first(@limit) : rows
  end

  # The `dhash: nil` guard lives IN the UPDATE, so filling is atomic
  # with respect to anything else writing dhashes (ImageDhashJob on a
  # fresh upload). update_all skips callbacks and does not touch
  # updated_at -- required, not incidental (#4808 URL tokens).
  def apply_one(id, dhash)
    filled = Image.where(id: id, dhash: nil).update_all(dhash: dhash)
    outcome = filled == 1 ? :filled : classify_unfilled(id, dhash)
    @stats[outcome] += 1
    puts("  image #{id}: #{outcome}") if verbose?
  end

  def classify_unfilled(id, dhash)
    existing = Image.where(id: id).pick(:dhash)
    if existing.nil?
      warn("  image #{id}: MISSING (no such image)")
      :missing
    elsif existing == dhash
      :already_set
    else
      warn("  image #{id}: MISMATCH (existing #{existing}, csv #{dhash})")
      :mismatch
    end
  end

  def verbose?
    @limit && @limit <= VERBOSE_LIMIT
  end

  def report_progress(done, total)
    now = Time.current
    return if now - @last_report_at < @report_interval

    @last_report_at = now
    warn("  #{pace_report(done, total, now)} -- " \
         "#{@stats.sort.map { |k, v| "#{k}: #{v}" }.join(", ")}")
  end

  def pace_report(done, total, now)
    rate = done / [(now - @started_at).to_f, 0.001].max
    left = rate.positive? ? (total - done) / rate : 0
    format("%d/%d (%.1f%%) %.1f/s, ~%ds left",
           done, total, 100.0 * done / [total, 1].max, rate, left)
  end

  def summarize
    elapsed = (Time.current - @started_at).round
    puts("\nTotals (#{elapsed}s): " \
         "#{@stats.sort.map { |k, v| "#{k}: #{v}" }.join(", ")}")
  end
end

options = {}
OptionParser.new do |opts|
  opts.on("--export FILE", "Write id,dhash CSV of local hashes") do |f|
    options[:export] = f
  end
  opts.on("--apply FILE", "Apply id,dhash CSV (fill-NULL-only)") do |f|
    options[:apply] = f
  end
  opts.on("--limit N", Integer, "Apply only the first N rows") do |n|
    options[:limit] = n
  end
  opts.on("--report-interval N", Integer,
          "Seconds between progress reports (default 10)") do |n|
    options[:report_interval] = n
  end
end.parse!

TransferImageDhashes.new(options).run
