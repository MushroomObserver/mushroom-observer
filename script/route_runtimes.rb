#!/usr/bin/env ruby
# frozen_string_literal: true

# Scan (gzipped) production logs and report, per route, the total time spent
# and the median runtime over a date window. Standalone Ruby — no Rails boot,
# streams each file line-by-line, so it's light on the server. Still, prefer
# running off-peak / niced (`nice -n19 ruby script/route_runtimes.rb ...`).
#
# A route is controller + action (e.g. "rss_logs show",
# "observations/maps index"), parsed from the request-stats TIME line that
# app/controllers/application_controller.rb logs:
#
#   W, [2026-06-21T18:03:22.316401 #2379965]  WARN -- : \
#     TIME: 0.00348845 302 rss_logs show user 201.227.43.116  https://...  UA
#         elapsed^      status^  ctrl^  action^ robot^
#
# Counts SUCCESSFUL (2xx), non-robot requests only. Each line is included by
# its own timestamp (not the filename date), so the log-rotation naming
# scheme doesn't matter for correctness; filename dates are only a coarse
# skip (±2 day margin) to avoid reading files clearly outside the window.
#
# Usage:
#   ruby script/route_runtimes.rb [--start YYYY-MM-DD] [--end YYYY-MM-DD]
#                                 [--logdir DIR] [--out FILE] [--top N]
#
# Defaults: window = trailing 30 days (today-30 .. today, inclusive);
# logdir = /var/web/mo/log; out = route_runtimes_<start>_to_<end>.csv;
# top = 30 (rows printed to stdout). Writes the full sorted CSV AND prints a
# top-N table.

require "date"
require "zlib"
require "optparse"
require "csv"

class RouteRuntimes
  # date, elapsed, status, controller, action, robot
  LINE_RE = /
    \[(\d{4}-\d{2}-\d{2})T[\d:.]+[^\]]*\]   # [2026-06-21T18:03:22.316401 #pid]
    .*?\bTIME:\s+
    (\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)
  /x

  PROGRESS_EVERY = 1_000_000

  def initialize(opts)
    @start = opts.fetch(:start)
    @end = opts.fetch(:end)
    @logdir = opts.fetch(:logdir)
    @out = opts.fetch(:out)
    @top = opts.fetch(:top)
    @durations = Hash.new { |h, k| h[k] = [] }
    @lines = 0
    @scanned = 0
    @counted = 0
    @bytes_done = 0   # on-disk bytes of fully-scanned files
    @total_bytes = 0
    @current_io = nil # stream of the file being scanned (for ETA)
  end

  def run
    files = discover_files
    @total_bytes = files.sum { |path| file_size(path) }
    @started = clock
    warn("Scanning #{files.size} file(s) for #{@start}..#{@end} " \
         "(2xx, non-robot)")
    files.each_with_index { |path, i| scan_file(path, i + 1, files.size) }
    rows = summarize
    write_csv(rows)
    print_table(rows)
    report_done(rows.size)
  end

  private

  def report_done(route_count)
    warn(format("Done in %s: %d lines, %d counted, %d routes -> %s",
                hms(clock - @started), @scanned, @counted, route_count, @out))
  end

  def clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def hms(secs)
    s = secs.round
    format("%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
  end

  # --- file discovery ---

  # Current live log + rotated (plain) + archived (.gz). Bare production.log
  # has no date so it's always scanned; dated files are skipped only when
  # clearly outside the window (±2 days, since the rotation date can lag the
  # content date by ~1 day).
  def discover_files
    files = []
    live = File.join(@logdir, "production.log")
    files << live if File.exist?(live)
    files.concat(dated_files(File.join(@logdir, "production.log-[0-9]*")))
    files.concat(dated_files(File.join(@logdir, "old",
                                       "production.log-[0-9]*.gz")))
    files
  end

  def dated_files(glob)
    lo = @start - 2
    hi = @end + 2
    Dir.glob(glob).select { |path| keep_dated_file?(path, lo, hi) }
  end

  # Skip files clearly outside the window. An undateable name is skipped
  # (with a warning) rather than scanned — these globs only match dated
  # files, and the bare production.log is added separately.
  def keep_dated_file?(path, low, high)
    date = filename_date(path)
    if date.nil?
      warn("  skip #{File.basename(path)}: no parseable YYYYMMDD in name")
      return false
    end
    date.between?(low, high)
  end

  # Date from production.log-YYYYMMDD, with or without a -N rotation suffix
  # and/or .gz (e.g. production.log-20250427-2.gz -> 2025-04-27).
  def filename_date(path)
    m = /production\.log-(\d{8})/.match(path)
    m && Date.strptime(m[1], "%Y%m%d")
  rescue Date::Error
    nil
  end

  # --- scanning ---

  def scan_file(path, idx, total)
    warn(format("[%d/%d] %s (%s) %s", idx, total, File.basename(path),
                human_size(path), eta_text))
    each_line(path) do |line|
      @lines += 1
      consume(line)
      report_progress if (@lines % PROGRESS_EVERY).zero?
    end
  rescue Zlib::GzipFile::Error, IOError, SystemCallError => e
    warn("  skip #{path}: #{e.class}: #{e.message}")
  ensure
    @bytes_done += file_size(path)
  end

  def report_progress
    elapsed = clock - @started
    rate = elapsed.positive? ? (@lines / elapsed).round : 0
    warn(format("  %s | %d lines | %d counted | %d lines/s | %s",
                hms(elapsed), @lines, @counted, rate, eta_text))
  end

  # ETA from the fraction of total on-disk bytes processed (completed files
  # plus the current file's stream position). Plain bytes process faster than
  # .gz bytes (no decompression), so the estimate is roughest while the two
  # uncompressed production.log files are scanned and tightens over the .gz
  # set.
  def eta_text
    cur = processed_bytes
    elapsed = clock - @started
    return "ETA --" unless @total_bytes.positive? && cur.positive? &&
                           elapsed.positive?

    frac = cur.to_f / @total_bytes
    remaining = elapsed * (1.0 - frac) / frac
    format("%d%% done, ETA %s", (frac * 100).round, hms(remaining))
  end

  def processed_bytes
    @bytes_done + (@current_io&.pos || 0)
  end

  def file_size(path)
    File.size(path)
  rescue SystemCallError
    0
  end

  def human_size(path)
    format("%.1f MB", file_size(path).to_f / (1024 * 1024))
  end

  def each_line(path, &block)
    @current_io = File.open(path, "rb")
    reader = if path.end_with?(".gz")
               Zlib::GzipReader.new(@current_io)
             else
               @current_io
             end
    reader.each_line(&block)
  ensure
    @current_io&.close
    @current_io = nil
  end

  def consume(line)
    line = line.scrub unless line.valid_encoding?
    m = LINE_RE.match(line)
    return unless m

    @scanned += 1
    fields = m.captures # date, elapsed, status, controller, action, robot
    return unless countable?(fields)

    secs = fields[1].to_f
    return unless secs.finite? && secs >= 0

    @durations["#{fields[3]} #{fields[4]}"] << secs
    @counted += 1
  end

  # 2xx, non-robot, in the date window. Lexicographic date compare is
  # correct for YYYY-MM-DD strings.
  def countable?(fields)
    date, _elapsed, status, = fields
    robot = fields[5]
    date.between?(@start.to_s, @end.to_s) &&
      status.start_with?("2") && robot != "robot"
  end

  # --- summarize / output ---

  def summarize
    rows = @durations.map do |route, secs|
      { route: route, count: secs.size,
        total_seconds: secs.sum.round(3),
        median_seconds: median(secs).round(6) }
    end
    rows.sort_by { |r| -r[:total_seconds] }
  end

  def median(values)
    sorted = values.sort
    n = sorted.size
    mid = n / 2
    n.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end

  def write_csv(rows)
    CSV.open(@out, "w") do |csv|
      csv << %w[route count total_seconds median_seconds]
      rows.each do |r|
        csv << [r[:route], r[:count], r[:total_seconds], r[:median_seconds]]
      end
    end
  end

  def print_table(rows)
    puts(format("\nTop %d routes by total time (%s..%s):", @top, @start, @end))
    puts("route                                  count      total_s   median_s")
    rows.first(@top).each do |r|
      puts(format("%-34s %9d %12.3f %10.6f",
                  r[:route], r[:count], r[:total_seconds], r[:median_seconds]))
    end
  end
end

# Standalone script (no Rails/ActiveSupport), so plain Date is correct here.
def parse_options(argv)
  today = Date.today # rubocop:disable Rails/Date
  opts = { start: today - 30, end: today, logdir: "/var/web/mo/log",
           out: nil, top: 30 }
  option_parser(opts).parse!(argv)
  opts[:start] = to_date(opts[:start])
  opts[:end] = to_date(opts[:end])
  opts[:out] ||= "route_runtimes_#{opts[:start]}_to_#{opts[:end]}.csv"
  opts
end

def to_date(value)
  value.is_a?(Date) ? value : Date.parse(value)
end

def option_parser(opts)
  OptionParser.new do |o|
    o.banner = "Usage: ruby script/route_runtimes.rb [options]"
    o.on("--start DATE", "First day (YYYY-MM-DD), inclusive") do |v|
      opts[:start] = v
    end
    o.on("--end DATE", "Last day (YYYY-MM-DD), inclusive") do |v|
      opts[:end] = v
    end
    o.on("--logdir DIR", "Log directory (default /var/web/mo/log)") do |v|
      opts[:logdir] = v
    end
    o.on("--out FILE", "CSV output path") { |v| opts[:out] = v }
    o.on("--top N", Integer, "Rows to print (default 30)") do |v|
      opts[:top] = v
    end
  end
end

RouteRuntimes.new(parse_options(ARGV)).run if $PROGRAM_NAME == __FILE__
