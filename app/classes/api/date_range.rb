# encoding: utf-8

class API
  # Parses and returns ranges of dates
  class DateRange
    PARSERS = [:date_range, :month_range, :year_range,
               :month_day_range, :just_month_range,
               :date, :month, :year,
               :month_day, :just_month]

    def self.parse(str)
      PARSERS.each do |parser|
        match = send(parser, str)
        return match if match
      end
      fail BadParameterValue.new(str, :date_range)
    rescue ArgumentError
      raise BadParameterValue.new(str, :date_range)
    end

    def self.date_range(str)
      match = Patterns.date_range(str)
      return unless match
      OrderedRange.new(Date.parse(match[1]), Date.parse(match[3]))
    end

    def self.month_range(str)
      match = Patterns.month_range(str)
      return unless match
      from, to = [match[1], match[3]].sort
      suffix = match[2] + "01"
      OrderedRange.new(Date.parse(from + suffix),
                       Date.parse(to + suffix).next_month.prev_day)
    end

    def self.year_range(str)
      match = Patterns.year_range(str)
      return unless match
      from = match[1]
      to = match[2]
      if from > "1500" && to > "1500"
        from, to = to, from if from > to
        return OrderedRange.new(Date.parse(from + "0101"),
                                Date.parse(to + "0101").next_year.prev_day)
      end
    end

    def self.month_day_range(str)
      match = Patterns.month_day_range(str)
      return unless match
      day1 = calc_monthday(match[2].to_i, match[3].to_i)
      day2 = calc_monthday(match[5].to_i, match[6].to_i)
      OrderedRange.new(day1, day2, :leave_order)
    end

    def self.calc_monthday(month, day)
      fail BadParameterValue.new(str, :date_range) if bad_month(month) ||
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
      match = Patterns.just_month_range(str)
      return unless match
      from = match[1].to_i
      to = match[2].to_i
      if bad_month(from) || bad_month(to)
        fail BadParameterValue.new(str, :date_range)
      end
      OrderedRange.new(from, to, :leave_order)
    end

    def self.date(str)
      return Date.parse(str) if Patterns.date(str)
    end

    def self.month(str)
      match = Patterns.month(str)
      return unless match
      start = Date.parse(str + match[2] + "01")
      OrderedRange.new(start, start.next_month.prev_day)
    end

    def self.year(str)
      return unless Patterns.year(str) && str > "1500"
      start = Date.parse(str + "0101")
      OrderedRange.new(start, start.next_year.prev_day)
    end

    def self.month_day(str)
      match = Patterns.month_day(str)
      return unless match
      day = calc_monthday(match[1].to_i, match[3].to_i)
      OrderedRange.new(day, day)
    end

    def self.just_month(str)
      return unless Patterns.just_month(str)
      val = str.to_i
      fail BadParameterValue.new(str, :date_range) if bad_month(val)
      OrderedRange.new(val, val)
    end
  end
end
