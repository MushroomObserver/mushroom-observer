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

# Outage period: Jan 14 00:00 UTC through Feb 17 (when creds were fixed)
START_DATE = "20260114"
END_DATE = "20260217"

count = 0

def process_log_lines(lines, source)
  entries = []
  i = 0
  while i < lines.size
    line = lines[i]

    # Look for the POST to webmaster_questions
    if line.include?('POST "/admin/emails/webmaster_questions"')
      # Extract timestamp from this line
      timestamp = line[/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/]

      # Scan ahead for the Parameters line (usually 2 lines later)
      search_end = [i + 5, lines.size].min
      (i + 1...search_end).each do |j|
        next unless lines[j].include?("Parameters:")

        params_line = lines[j]

        reply_to = params_line[/"reply_to"=>"([^"]*)"/, 1]
        # Message sits between "message"=>" and the closing ", "commit"
        # or "}} at end of params
        message = params_line[/"message"=>"(.*?)",\s*"commit"/, 1] ||
                  params_line[/"message"=>"(.*?)"\}\}/, 1] ||
                  params_line[/"message"=>"(.*?)"/, 1]

        next unless reply_to

        # Unescape \r\n to actual newlines for readability
        message = message.to_s
                         .gsub('\r\n', "\n")
                         .gsub('\n', "\n")
                         .gsub('\r', "")

        entries << {
          timestamp: timestamp || "unknown",
          source: source,
          reply_to: reply_to,
          message: message
        }
        break
      end
    end

    i += 1
  end
  entries
end

# Collect relevant gzipped log files
gz_files = Dir.glob("#{LOG_DIR}/old/production.log-*.gz").select do |f|
  date = f[/(\d{8})\.gz$/, 1]
  date && date >= START_DATE && date <= END_DATE
end.sort

OUTPUT.puts("=" * 60)
OUTPUT.puts("Webmaster Questions During Email Outage")
OUTPUT.puts("Period: #{START_DATE} - #{END_DATE}")
OUTPUT.puts("Extracted: #{Time.now.utc.strftime('%Y-%m-%d %H:%M:%S UTC')}")
OUTPUT.puts("=" * 60)
OUTPUT.puts

# Process gzipped log files
gz_files.each do |gz_file|
  date = gz_file[/(\d{8})\.gz$/, 1]
  $stderr.puts("Scanning #{File.basename(gz_file)}...")

  lines = []
  Zlib::GzipReader.open(gz_file) do |gz|
    gz.each_line { |line| lines << line }
  end

  entries = process_log_lines(lines, date)
  entries.each do |entry|
    count += 1
    OUTPUT.puts("--- ##{count} ---")
    OUTPUT.puts("Date:  #{entry[:timestamp]} UTC")
    OUTPUT.puts("From:  #{entry[:reply_to]}")
    OUTPUT.puts("Log:   production.log-#{entry[:source]}.gz")
    OUTPUT.puts
    OUTPUT.puts(entry[:message])
    OUTPUT.puts
  end
end

# Also check current production.log
current_log = "#{LOG_DIR}/production.log"
if File.exist?(current_log)
  $stderr.puts("Scanning production.log (current)...")
  lines = File.readlines(current_log)
  entries = process_log_lines(lines, "current")
  entries.each do |entry|
    count += 1
    OUTPUT.puts("--- ##{count} ---")
    OUTPUT.puts("Date:  #{entry[:timestamp]} UTC")
    OUTPUT.puts("From:  #{entry[:reply_to]}")
    OUTPUT.puts("Log:   production.log (current)")
    OUTPUT.puts
    OUTPUT.puts(entry[:message])
    OUTPUT.puts
  end
end

OUTPUT.puts("=" * 60)
OUTPUT.puts("Total: #{count} webmaster question(s) found")
OUTPUT.puts("=" * 60)

OUTPUT.close if ARGV[1]
$stderr.puts("Done. Found #{count} webmaster question(s).")
