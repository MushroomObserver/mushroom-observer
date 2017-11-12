# API
class API
  # Class encapsulating a range of dates.
  class DateRange
    PARSERS = [:date_range, :month_range, :year_range,
               :month_day_range, :just_month_range,
               :date, :month, :year,
               :month_day, :just_month].freeze

    def self.parse(str)
      PARSERS.each do |parser|
        match = send(parser, str)
        return match if match
      end
      raise BadParameterValue.new(str, :date_range)
    rescue ArgumentError
      raise BadParameterValue.new(str, :date_range)
    end

    def self.date_range(str)
      match = Patterns.range_matcher(str, Patterns.date_patterns)
      Patterns.ordered_range(Date, match, 1, 3)
    end

    def self.month_range(str)
      match = Patterns.range_matcher(str, Patterns.month_patterns)
      return unless match
      from, to = [match[1], match[3]].sort
      suffix = match[2] + "01"
      OrderedRange.new(Date.parse(from + suffix),
                       Date.parse(to + suffix).next_month.prev_day)
    end

    def self.year_range(str)
      match = Patterns.range_matcher(str, [Patterns.year_pattern])
      return unless match
      from, to = [match[1], match[2]].sort
      return if from < "1500" || to < "1500"
      from = Date.parse(from + "0101")
      to   = Date.parse(to + "0101").next_year.prev_day
      OrderedRange.new(from, to)
    end

    def self.month_day_range(str)
      match = Patterns.range_matcher(str, Patterns.month_day_patterns)
      return unless match
      day1 = calc_monthday(match[2].to_i, match[3].to_i)
      day2 = calc_monthday(match[5].to_i, match[6].to_i)
      OrderedRange.new(day1, day2, :leave_order)
    end

    def self.calc_monthday(month, day)
      raise BadParameterValue.new(str, :date_range) if bad_month(month) ||
                                                       bad_day(day)
      month * 100 + day
    end

    def self.bad_month(month)
      month < 1 || month > 12
    end

    def self.bad_day(day)
      day < 1 || day > 31
    end

    def self.just_month_range(str)
      match = Patterns.range_matcher(str, [Patterns.month_pattern])
      return unless match
      from = match[1].to_i
      to = match[2].to_i
      if bad_month(from) || bad_month(to)
        raise BadParameterValue.new(str, :date_range)
      end
      OrderedRange.new(from, to, :leave_order)
    end

    def self.date(str)
      return Date.parse(str) if Patterns.list_matcher(str,
                                                      Patterns.date_patterns)
    end

    def self.month(str)
      match = Patterns.list_matcher(str, Patterns.month_patterns)
      return unless match
      start = Date.parse(str + match[2] + "01")
      OrderedRange.new(start, start.next_month.prev_day)
    end

    def self.year(str)
      return unless Patterns.list_matcher(str, [Patterns.year_pattern]) &&
                    str > "1500"
      start = Date.parse(str + "0101")
      OrderedRange.new(start, start.next_year.prev_day)
    end

    def self.month_day(str)
      match = Patterns.list_matcher(str, Patterns.month_day_patterns)
      return unless match
      day = calc_monthday(match[1].to_i, match[3].to_i)
      OrderedRange.new(day, day)
    end

    def self.just_month(str)
      return unless Patterns.list_matcher(str, [Patterns.month_pattern])
      val = str.to_i
      raise BadParameterValue.new(str, :date_range) if bad_month(val)
      OrderedRange.new(val, val)
    end
  end
end
