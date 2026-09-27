# frozen_string_literal: true

# Reports what MO has exchanged with each external site (#5416, #2320).
# Limits live on the site rows, so a new data source needs no change
# here -- and a site that publishes no limit is still reported, since
# knowing how hard MO leans on a partner is useful without a cap to
# compare against.

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

def limit_line(limit, used, cap)
  share = 100.0 * used / cap
  format("  %-22s %12s of %-10s %5.1f%%%s", limit.label,
         format_usage(used, limit.units), format_usage(cap, limit.units),
         share, usage_flag(share))
end

# For a site with no published limit, or a counter no limit covers.
def total_line(label, value, units)
  format("  %-22s %12s", label, format_usage(value, units))
end

def report_site_usage(site)
  puts("#{site.name}, as of #{Time.zone.now}")
  ExternalSiteUsage.against_limits(site).each do |limit, used, cap|
    puts(limit_line(limit, used, cap))
  end
  report_uncapped_totals(site)
  report_busiest_bucket(site)
end

# Whatever the limits did not already cover, over the trailing day, so a
# site with no limits still shows its traffic.
def report_uncapped_totals(site)
  capped = ExternalSiteUsage.against_limits(site).
           map { |limit, _used, _cap| limit.counter }.uniq
  totals = ExternalSiteUsage.totals_since(site, 1.day)
  (ExternalSiteUsage::COUNTERS - capped).each do |counter|
    units = counter == :requests ? :count : :bytes
    label = "#{counter.to_s.tr("_", " ")}, trailing day"
    puts(total_line(label, totals[counter], units))
  end
end

def report_busiest_bucket(site)
  busiest = site.external_site_usages.order(bytes_in: :desc).first
  return puts("  no usage recorded yet") unless busiest

  puts("  busiest ten minutes: #{busiest.bucket_start} " \
       "in #{format_usage(busiest.bytes_in, :bytes)}, " \
       "out #{format_usage(busiest.bytes_out, :bytes)}, " \
       "#{busiest.requests} requests")
end

# Grouped in Ruby rather than with a SQL date function: a month is at
# most 4,320 ten-minute rows per site, and .claude/rules/no_raw_sql.md
# rules out the DATE()/SUM() strings this would otherwise need.
def report_site_history(site, days)
  by_day = history_by_day(site, days)
  return puts("#{site.name}: nothing in the last #{days} days") if by_day.empty?

  puts("#{site.name}, last #{days} days")
  puts("  day            requests      bytes in     bytes out")
  by_day.keys.sort.reverse_each { |day| puts(history_line(day, by_day[day])) }
end

def history_by_day(site, days)
  site.external_site_usages.
    where(bucket_start: days.days.ago..).
    pluck(:bucket_start, :requests, :bytes_in, :bytes_out).
    group_by { |start, _r, _i, _o| start.to_date }
end

def history_line(day, rows)
  format("  %-12s %10d %13s %13s", day,
         rows.sum { |_s, r, _i, _o| r },
         format_usage(rows.sum { |_s, _r, i, _o| i }, :bytes),
         format_usage(rows.sum { |_s, _r, _i, o| o }, :bytes))
end

# SITE=<name> narrows to one site; otherwise every site with a published
# limit or any recorded usage.
def usage_sites
  named = ENV.fetch("SITE", nil)
  return ExternalSite.where(name: named) if named.present?

  ExternalSite.all.select do |site|
    ExternalSiteUsage.against_limits(site).any? ||
      site.external_site_usages.any?
  end
end

namespace :external_sites do
  desc "Report usage against each site's published limits (SITE=name)"
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
