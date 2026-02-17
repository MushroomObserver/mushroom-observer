#!/usr/bin/env ruby
# frozen_string_literal: true

# Extract webmaster question submissions from production logs during
# the email outage period (Jan 14 - Feb 17, 2026).
#
# These submissions were enqueued via SolidQueue but delivery failed
# silently due to broken gmail_smtp_settings_webmaster credentials.
# The log Parameters lines contain the full message content.
#
# USAGE (run on production server):
#   ruby script/extract_webmaster_emails.rb > /tmp/missed_webmaster_emails.txt
#
#   # Or specify custom log dir and output file:
#   ruby script/extract_webmaster_emails.rb /var/web/mo/log /tmp/output.txt

require "zlib"

LOG_DIR = ARGV[0] || "/var/web/mo/log"
OUTPUT = ARGV[1] ? File.open(ARGV[1], "w") : $stdout

# Outage period: Jan 14 00:00 UTC through Feb 17 (when creds fixed)
START_DATE = "20260114"
END_DATE = "20260217"
# Lines to search after a POST for the Parameters line
LOOKAHEAD = 5

count = 0

# Stream log lines and extract webmaster question entries.
# Uses a small lookahead buffer instead of loading the entire file.
def scan_lines(enumerable, source)
  entries = []
  post_timestamp = nil
  lines_remaining = 0

  enumerable.each do |line|
    if lines_remaining.positive?
      lines_remaining -= 1
      entry = try_parse_params(line, post_timestamp, source)
      if entry
        entries << entry
        lines_remaining = 0
      end
    end

    next unless line.include?(
      'POST "/admin/emails/webmaster_questions"'
    )

    post_timestamp = line[/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/]
    lines_remaining = LOOKAHEAD
  end
  entries
end

def try_parse_params(line, timestamp, source)
  return unless line.include?("Parameters:")

  reply_to, message = parse_params(line)
  return unless reply_to

  { timestamp: timestamp || "unknown", source: source,
    reply_to: reply_to, message: message }
end

def parse_params(params_line)
  reply_to = params_line[/"reply_to"=>"([^"]*)"/, 1]
  message = params_line[/"message"=>"(.*?)",\s*"commit"/, 1] ||
            params_line[/"message"=>"(.*?)"\}\}/, 1] ||
            params_line[/"message"=>"(.*?)"/, 1]
  message = unescape_message(message)
  [reply_to, message]
end

def unescape_message(message)
  message.to_s.
    gsub('\r\n', "\n").
    gsub('\n', "\n").
    gsub('\r', "")
end

def print_entry(entry, count)
  OUTPUT.puts("--- ##{count} ---")
  OUTPUT.puts("Date:  #{entry[:timestamp]} UTC")
  OUTPUT.puts("From:  #{entry[:reply_to]}")
  OUTPUT.puts("Log:   #{entry[:source]}")
  OUTPUT.puts
  OUTPUT.puts(entry[:message])
  OUTPUT.puts
end

# Collect relevant gzipped log files
gz_files = Dir.glob("#{LOG_DIR}/old/production.log-*.gz").select do |f|
  date = f[/(\d{8})\.gz$/, 1]
  date && date >= START_DATE && date <= END_DATE
end.sort

OUTPUT.puts("=" * 60)
OUTPUT.puts("Webmaster Questions During Email Outage")
OUTPUT.puts("Period: #{START_DATE} - #{END_DATE}")
OUTPUT.puts("Extracted: #{Time.now.utc.strftime("%Y-%m-%d %H:%M:%S UTC")}")
OUTPUT.puts("=" * 60)
OUTPUT.puts

# Process gzipped log files (streamed)
gz_files.each do |gz_file|
  basename = File.basename(gz_file)
  warn("Scanning #{basename}...")

  entries = Zlib::GzipReader.open(gz_file) do |gz|
    scan_lines(gz.each_line, basename)
  end

  entries.each do |entry|
    count += 1
    print_entry(entry, count)
  end
end

# Also check current production.log (streamed)
current_log = "#{LOG_DIR}/production.log"
if File.exist?(current_log)
  warn("Scanning production.log (current)...")
  entries = scan_lines(
    File.foreach(current_log), "production.log (current)"
  )
  entries.each do |entry|
    count += 1
    print_entry(entry, count)
  end
end

OUTPUT.puts("=" * 60)
OUTPUT.puts("Total: #{count} webmaster question(s) found")
OUTPUT.puts("=" * 60)

OUTPUT.close if ARGV[1]
warn("Done. Found #{count} webmaster question(s).")
