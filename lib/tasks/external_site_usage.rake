# frozen_string_literal: true

# Reports what MO has spent against each external site's published rate
# limits (#5416, #2320). The limits live on the site rows, so a new data
# source needs no change here.

def format_usage(value, units)
  return value.to_s if units == :count

  format("%.2f GB", value / (1024.0**3))
end

def usage_flag(share)
  if share >= 80 then "  <-- over 80%"
  elsif share >= 50 then "  <-- over half"
  else ""
  end
end

def report_limit_line(limit, used, cap)
  share = 100.0 * used / cap
  format("  %-24s %12s of %-10s %5.1f%%%s", limit.label,
         format_usage(used, limit.units), format_usage(cap, limit.units),
         share, usage_flag(share))
end

def report_site_usage(site)
  rows = ExternalSiteUsage.against_limits(site)
  return puts("#{site.name}: no published limits recorded") if rows.empty?

  puts("#{site.name}, as of #{Time.zone.now}")
  rows.each { |limit, used, cap| puts(report_limit_line(limit, used, cap)) }
  report_busiest_bucket(site)
end

def report_busiest_bucket(site)
  busiest = site.external_site_usages.order(media_bytes: :desc).first
  return puts("  no usage recorded yet") unless busiest

  puts("  busiest ten minutes: #{busiest.bucket_start} " \
       "#{format_usage(busiest.media_bytes, :bytes)}, " \
       "#{busiest.requests} requests")
end

# Grouped in Ruby rather than with a SQL date function: a month is at
# most 4,320 ten-minute rows per site, and .claude/rules/no_raw_sql.md
# rules out the DATE()/SUM() strings this would otherwise need.
def report_site_history(site, days)
  by_day = history_by_day(site, days)
  return puts("#{site.name}: nothing in the last #{days} days") if by_day.empty?

  puts("#{site.name}, last #{days} days")
  puts("  day            requests        media")
  by_day.keys.sort.reverse_each { |day| puts(history_line(day, by_day[day])) }
end

def history_by_day(site, days)
  site.external_site_usages.
    where(bucket_start: days.days.ago..).
    pluck(:bucket_start, :requests, :media_bytes).
    group_by { |start, _r, _b| start.to_date }
end

def history_line(day, rows)
  format("  %-12s %10d %12s", day, rows.sum { |_s, r, _b| r },
         format_usage(rows.sum { |_s, _r, b| b }, :bytes))
end

# SITE=<name> narrows to one site; otherwise every site with a limit or
# recorded usage.
def usage_sites
  named = ENV.fetch("SITE", nil)
  return ExternalSite.where(name: named) if named.present?

  ExternalSite.all.select do |site|
    ExternalSiteUsage.against_limits(site).any? ||
      site.external_site_usages.any?
  end
end

namespace :external_sites do
  desc "Report usage against each site's published rate limits (SITE=name)"
  task usage: :environment do
    sites = usage_sites
    if sites.empty?
      next puts("no sites with published limits or recorded usage")
    end

    sites.each { |site| report_site_usage(site) }
  end

  desc "Report usage per day, most recent first (DAYS=30, SITE=name)"
  task usage_history: :environment do
    days = (ENV["DAYS"] || 30).to_i
    usage_sites.each { |site| report_site_history(site, days) }
  end
end
