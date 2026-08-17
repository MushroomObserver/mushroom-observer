# frozen_string_literal: true

# Parses user-input date ranges (or strings) into a range of Ruby dates that
# MO's date AR scopes can handle.
#
# Can parse ranges like "2008-01-05,2008-03-14" (comma between the two
# endpoints) or the dash-only "2008-01-05-2008-03-14", "2009-2011",
# "02-08" (month range), "09-03" (month range wrapping new year),
# and underscored Ruby-style phrases like "last_year", "1_day_ago", etc.
#
# Accessor
#     :range        returns an array or simple string representing a start date.
#
class DateRangeParser
  attr_reader :range

  # `endpoint:` is internal, set when parsing one side of a separated
  # range: endpoints don't nest, so "2026-08-12,2026-08-16,2026-08-17"
  # is rejected rather than silently spanned first-to-last.
  def initialize(string, endpoint: false)
    @string = string.to_s
    @endpoint = endpoint
    @range = parse_date_range
  end

  def parse_date_range
    return endpoint_range if @endpoint
    return parse_separated_range(",") if @string.include?(",")

    match_date_patterns(parse_date_words) || space_separated_range
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def match_date_patterns(val)
    a, b, c, d, e, f = val.split("-")
    case val
    when /^\d{4}$/
      yyyymmdd([a, 1, 1], [a, 12, 31])
    when /^\d{4}-\d\d?$/
      yyyymmdd([a, b, 1], [a, b, 31])
    when /^\d{4}-\d\d?-\d\d?$/
      yyyymmdd([a, b, c], [a, b, c])
    when /^\d{4}-\d{4}$/
      yyyymmdd([a, 1, 1], [b, 12, 31])
    when /^\d{4}-\d\d?-\d{4}-\d\d?$/
      yyyymmdd([a, b, 1], [c, d, 31])
    when /^\d{4}-\d\d?-\d\d?-\d{4}-\d\d?-\d\d?$/
      yyyymmdd([a, b, c], [d, e, f])
    when /^\d\d?$/
      mmdd([a, 1], [a, 31])
    when /^\d\d?-\d\d?$/
      mmdd([a, 1], [b, 31])
    when /^\d\d?-\d\d?-\d\d?-\d\d?$/
      mmdd([a, b], [c, d])
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  ##########################################################################

  private

  # "2026-08-12,2026-08-16": each side parses on its own (so "2026,2027"
  # and phrases like "last_month,today" work too); the range runs from
  # the left side's start to the right side's end. nil when either side
  # doesn't parse.
  def parse_separated_range(sep)
    left, right = @string.split(sep, 2).map(&:strip)
    from = self.class.new(left, endpoint: true).range
    to = self.class.new(right, endpoint: true).range
    return nil unless from && to

    [Array(from).first, Array(to).last]
  end

  # A space separates endpoints too ("2026-08-12 2026-08-16") -- but
  # only as a last resort, since spaces also occur inside date words
  # ("2 days ago" is one date, not a range).
  def space_separated_range
    return nil unless @string.include?(" ")

    parse_separated_range(" ")
  end

  # An endpoint may still contain spaces ("2 days ago") but never a
  # comma, and never another separated range.
  def endpoint_range
    return nil if @string.include?(",")

    match_date_patterns(parse_date_words)
  end

  def yyyymmdd(from, to)
    [format("%04<year>d-%02<month>d-%02<day>d",
            year: from.first, month: from.second.to_i,
            day: from.third.to_i),
     format("%04<year>d-%02<month>d-%02<day>d",
            year: to.first, month: to.second.to_i,
            day: [to.third.to_i, eom(to.first, to.second).to_i].min)]
  end

  def mmdd(from, to)
    [format("%02<year>d-%02<month>d",
            year: from.first.to_i, month: from.second.to_i),
     format("%02<year>d-%02<month>d",
            year: to.first.to_i, month: to.second.to_i)]
  end

  def eom(year, month)
    Date.new(year.to_i, month.to_i).end_of_month.strftime("%d")
  end

  # rubocop:disable Metrics/AbcSize
  def parse_date_words
    val = @string.dup
    val = val.tr!("_", " ") if val.include?("_")
    parse_date_word!(val, "today", :today, :day, 0)
    parse_date_word!(val, "yesterday", :yesterday, :day, 1)
    parse_date_word!(val, "\d+ days ago", :days_ago, :day, "N")
    parse_date_word!(val, "this week", :this_week, :week, 0)
    parse_date_word!(val, "last week", :last_week, :week, 1)
    parse_date_word!(val, "\d+ weeks ago", :weeks_ago, :week, "N")
    parse_date_word!(val, "this month", :this_month, :month, 0)
    parse_date_word!(val, "last month", :last_month, :month, 1)
    parse_date_word!(val, "\d+ months ago", :months_ago, :month, "N")
    parse_date_word!(val, "this year", :this_year, :year, 0)
    parse_date_word!(val, "last year", :last_year, :year, 1)
    parse_date_word!(val, "\d+ years ago", :years_ago, :year, "N")
    val
  end

  def parse_date_word!(val, english, tag, unit, num)
    translation = Regexp.escape(:"search_value_#{tag}".l).
                  sub(/\bN\b/, '\d+')
    # This bit of cleverness runs until there's nothing in line 1 to `sub!`
    1 while val.to_s.sub!(/(^|-)(#{english}|#{translation})(-|$)/) do |word|
      first = word.sub!(/-$/, "")
      last  = word.sub!(/^-/, "")
      num2  = num == "N" ? word.to_i : num
      date  = Date.current - num2.send(:"#{unit}s")
      left  = format_date(date.send(:"beginning_of_#{unit}")) unless last
      right = format_date(date.send(:"end_of_#{unit}")) unless first
      [left, right].join("-")
    end
  end
  # rubocop:enable Metrics/AbcSize

  def format_date(date)
    date.strftime("%Y-%m-%d")
  end
end
