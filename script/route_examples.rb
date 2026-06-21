#!/usr/bin/env ruby
# frozen_string_literal: true

# Extract the most recent N requests for a given route (controller + action)
# from the (gzipped) production logs, with full params and timing.
#
# Production logs at :info with the default Logger::Formatter, so each request
# is a block of lines sharing one "[timestamp #pid]". Puma runs one request
# per worker at a time (threads 1,1), so a given PID's lines are sequential:
#
#   I, [...#pid]  INFO -- : Started PATCH "/..." for 1.2.3.4 at ...
#   I, [...#pid]  INFO -- : Processing by Foo::BarController#edit as HTML
#   I, [...#pid]  INFO -- :   Parameters: {"id"=>"5", ...}
#   I, [...#pid]  INFO -- : Completed 200 OK in 523ms (Views: ... | AR: ...)
#   W, [...#pid]  WARN -- : TIME: 0.523 200 foo/bar edit user 1.2.3.4\turl\tUA
#
# We anchor on the TIME line (it carries the route + the canonical timing) and
# attach that PID's most recent Started / Parameters / Completed lines.
#
# Scans newest file first and stops once N matches are found, so it usually
# only reads the live log plus a file or two.
#
# Usage:
#   ruby script/route_examples.rb CONTROLLER ACTION [-n N] [--logdir DIR]
# e.g.
#   ruby script/route_examples.rb observations/species_lists edit -n 20

require "date"
require "zlib"
require "optparse"

class RouteExamples
  HEAD_RE = /\A[A-Z], \[([\d\-T:.+]+) \#(\d+)\][^:]*:\s?(.*)/
  STARTED_RE = /\AStarted (\S+) "([^"]*)"/
  PARAMS_RE = /\AParameters:\s*(.*)/m

  def initialize(controller:, action:, count:, logdir:)
    @controller = controller
    @action = action
    @count = count
    @logdir = logdir
  end

  def run
    records = collect
    print_records(records.sort_by { |r| r[:ts] }.last(@count).reverse)
  end

  private

  # Newest file first, stopping once we have enough matches.
  def collect
    files = candidate_files
    records = []
    files.each_with_index do |path, i|
      warn(format("[%d/%d] %s (have %d/%d)", i + 1, files.size,
                  File.basename(path), records.size, @count))
      records.concat(scan(path))
      break if records.size >= @count
    end
    records
  end

  # --- file discovery (newest first) ---

  def candidate_files
    files = []
    live = File.join(@logdir, "production.log")
    files << live if File.exist?(live)
    dated = Dir.glob(File.join(@logdir, "production.log-[0-9]*")) +
            Dir.glob(File.join(@logdir, "old", "production.log-[0-9]*.gz"))
    files + dated.sort_by { |p| filename_date(p) || Date.new(1900) }.reverse
  end

  def filename_date(path)
    m = /production\.log-(\d{8})/.match(path)
    m && Date.strptime(m[1], "%Y%m%d")
  rescue Date::Error
    nil
  end

  # --- scan one file ---

  def scan(path)
    @pending = Hash.new { |h, k| h[k] = {} }
    records = []
    each_line(path) do |line|
      parsed = parse_line(line)
      next unless parsed

      record = absorb(parsed)
      records << record if record
    end
    records
  rescue Zlib::GzipFile::Error, IOError, SystemCallError => e
    warn("  skip #{path}: #{e.class}: #{e.message}")
    records || []
  end

  def each_line(path, &block)
    if path.end_with?(".gz")
      Zlib::GzipReader.open(path) { |gz| gz.each_line(&block) }
    else
      File.open(path, "rb") { |f| f.each_line(&block) }
    end
  end

  # Update per-PID pending state; on a matching TIME line, emit the record.
  def absorb(parsed)
    pid, ts, kind, payload = parsed
    if kind == :time
      finish(pid, ts, payload)
    else
      @pending[pid][kind] = payload
      nil
    end
  end

  def finish(pid, timestamp, fields)
    pending = @pending.delete(pid) || {}
    return nil unless fields[:controller] == @controller &&
                      fields[:action] == @action

    build_record(timestamp, fields, pending)
  end

  def build_record(timestamp, fields, pending)
    started = pending[:started] || {}
    { ts: timestamp, elapsed: fields[:elapsed], status: fields[:status],
      ip: fields[:ip], url: fields[:url],
      method: started[:method], path: started[:path],
      params: pending[:params], completed: pending[:completed] }
  end

  # --- line parsing ---

  def parse_line(line)
    line = line.scrub unless line.valid_encoding?
    m = HEAD_RE.match(line)
    return nil unless m

    kind, payload = classify(m[3].strip)
    kind && [m[2], m[1], kind, payload]
  end

  def classify(msg)
    return [:time, parse_time(msg)] if msg.start_with?("TIME:")
    if (m = STARTED_RE.match(msg))
      return [:started, { method: m[1], path: m[2] }]
    end
    if (m = PARAMS_RE.match(msg))
      return [:params, m[1]]
    end
    return [:completed, msg] if msg.start_with?("Completed ")

    nil
  end

  # "TIME: elapsed status controller action robot ip\turl\tua"
  def parse_time(msg)
    head, url, = msg.split("\t")
    parts = head.split(/\s+/)
    { elapsed: parts[1], status: parts[2], controller: parts[3],
      action: parts[4], robot: parts[5], ip: parts[6], url: url }
  end

  # --- output ---

  def print_records(records)
    if records.empty?
      warn("No requests found for '#{@controller} #{@action}'")
      return
    end
    records.each { |r| print_one(r) }
  end

  def print_one(record)
    puts(record_header(record))
    puts("  params:    #{record[:params] || "(none logged)"}")
    puts("  url:       #{record[:url]}")
    puts("  ip:        #{record[:ip]}")
    puts("  completed: #{record[:completed]}") if record[:completed]
    puts
  end

  def record_header(record)
    format("=== %s  %ss  %s  %s %s", record[:ts], record[:elapsed],
           record[:status], record[:method], record[:path])
  end
end

def parse_options(argv)
  opts = { count: 10, logdir: "/var/web/mo/log" }
  parser = OptionParser.new do |o|
    o.banner = "Usage: ruby script/route_examples.rb CONTROLLER ACTION [opts]"
    o.on("-n", "--count N", Integer, "Examples to show (default 10)") do |v|
      opts[:count] = v
    end
    o.on("--logdir DIR", "Log directory (default /var/web/mo/log)") do |v|
      opts[:logdir] = v
    end
  end
  parser.parse!(argv)
  controller, action = argv
  abort(parser.help) unless controller && action
  opts.merge(controller: controller, action: action)
end

RouteExamples.new(**parse_options(ARGV)).run if $PROGRAM_NAME == __FILE__
