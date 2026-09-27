# frozen_string_literal: true

# iNat's published limits. Requests come from the API description
# (https://api.inaturalist.org/v1/swagger.json); the media caps come from
# https://www.inaturalist.org/pages/developers, which states a permanent
# block as the consequence.
INAT_LIMITS = [
  ["requests, trailing hour", :requests_since, 1.hour, 3600, :count],
  ["requests, trailing day", :requests_since, 1.day, 10_000, :count],
  ["media, trailing hour", :media_bytes_since, 1.hour, 5 * 1024**3, :bytes],
  ["media, trailing day", :media_bytes_since, 1.day, 24 * 1024**3, :bytes]
].freeze

def format_usage(value, kind)
  return value.to_s if kind == :count

  format("%.2f GB", value / (1024.0**3))
end

def report_limit(site, limit)
  label, method, window, cap, kind = limit
  used = ExternalSiteUsage.send(method, site, window)
  share = cap.zero? ? 0 : (100.0 * used / cap)
  flag = if share >= 80 then "  <-- over 80%"
         elsif share >= 50 then "  <-- over half"
         else ""
         end
  puts(format("  %-24s %12s of %-10s %5.1f%%%s", label,
              format_usage(used, kind), format_usage(cap, kind), share, flag))
end

def report_inat_usage
  site = ExternalSite.inaturalist
  puts("iNat usage as of #{Time.zone.now}")
  INAT_LIMITS.each { |limit| report_limit(site, limit) }
  report_busiest_bucket(site)
end

def report_busiest_bucket(site)
  busiest = ExternalSiteUsage.where(external_site_id: site.id).
            order(media_bytes: :desc).first
  return puts("no usage recorded yet") unless busiest

  puts("busiest ten minutes on record: #{busiest.bucket_start} " \
       "#{format_usage(busiest.media_bytes, :bytes)}, " \
       "#{busiest.requests} requests")
end

# Grouped in Ruby rather than with a SQL date function: a month is at
# most 4,320 ten-minute rows, and .claude/rules/no_raw_sql.md rules out
# the DATE()/SUM() strings this would otherwise need.
def report_inat_usage_history(days)
  by_day = usage_buckets(days).group_by { |start, _r, _b| start.to_date }
  return puts("no usage recorded in the last #{days} days") if by_day.empty?

  puts("day            requests        media")
  by_day.keys.sort.reverse_each { |day| puts(usage_day_line(day, by_day[day])) }
end

def usage_buckets(days)
  ExternalSiteUsage.where(external_site_id: ExternalSite.inaturalist.id).
    where(bucket_start: days.days.ago..).
    pluck(:bucket_start, :requests, :media_bytes)
end

def usage_day_line(day, rows)
  format("%-12s %10d %12s", day, rows.sum { |_s, r, _b| r },
         format_usage(rows.sum { |_s, _r, b| b }, :bytes))
end

namespace :inat do
  desc "Report iNat API and media usage against the published limits"
  task(usage: :environment) { report_inat_usage }

  desc "Report iNat usage per day, most recent first (DAYS=30)"
  task(usage_history: :environment) do
    report_inat_usage_history((ENV["DAYS"] || 30).to_i)
  end
end
