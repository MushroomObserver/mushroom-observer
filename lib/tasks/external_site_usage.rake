# frozen_string_literal: true

# What MO holds from, and has exchanged with, each external site (#5416,
# #2320). Every configured site is reported, whether or not it publishes
# a limit and whether or not anything has been recorded: "we have
# exchanged nothing with this site" is itself worth seeing.
#
# Limits live on the site rows, so a new data source needs no change
# here. This is the command-line form of what belongs on an admin page.

def commas(number)
  ActiveSupport::NumberHelper.number_to_delimited(number.to_i)
end

def format_usage(value, units)
  return commas(value) if units == :count

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
  format("  %-24s %14s of %-10s %5.1f%%%s", limit.label,
         format_usage(used, limit.units), format_usage(cap, limit.units),
         share, usage_flag(share))
end

def total_line(label, value, units)
  format("  %-24s %14s", label, format_usage(value, units))
end

# What MO holds that came from or points at this site.
def inventory_line(site)
  counts = site.link_counts
  format("  %-24s %14s  (observations %s, images %s)", "links held",
         commas(counts.total), commas(counts.observations),
         commas(counts.images))
end

# Everything recorded, not just a trailing window -- the lifetime figure
# is what answers "how much have we moved between these sites".
def lifetime_line(site)
  total = ExternalSiteUsage.lifetime(site)
  return "  no traffic recorded" unless total.since

  format("  %-24s %14s  (in %s, out %s, since %s)", "requests, lifetime",
         commas(total.requests), format_usage(total.bytes_in, :bytes),
         format_usage(total.bytes_out, :bytes), total.since.to_date)
end

def report_site_usage(site)
  puts("#{site.name}, as of #{Time.zone.now}")
  puts(inventory_line(site))
  ExternalSiteUsage.against_limits(site).each do |limit, used, cap|
    puts(limit_line(limit, used, cap))
  end
  report_uncapped_totals(site)
  puts(lifetime_line(site))
end

# Whatever the limits did not already cover, over the trailing day, so a
# site with no published limit still shows its recent traffic.
def report_uncapped_totals(site)
  ExternalSiteUsage.uncapped_totals(site, 1.day).each do |counter, value|
    units = counter == :requests ? :count : :bytes
    puts(total_line("#{counter.to_s.tr("_", " ")}, trailing day",
                    value, units))
  end
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

# Every site, so a site MO has exchanged nothing with is visibly at zero
# rather than missing. SITE=<name> narrows to one.
def usage_sites
  named = ENV.fetch("SITE", nil)
  return ExternalSite.where(name: named).order(:name) if named.present?

  ExternalSite.order(:name)
end

namespace :external_sites do
  desc "Report holdings and usage per external site (SITE=name)"
  task usage: :environment do
    sites = usage_sites
    next puts("no external sites configured") if sites.empty?

    sites.each { |site| report_site_usage(site) }
  end

  desc "Report usage per day, most recent first (DAYS=30, SITE=name)"
  task usage_history: :environment do
    days = (ENV["DAYS"] || 30).to_i
    usage_sites.each { |site| report_site_history(site, days) }
  end
end
