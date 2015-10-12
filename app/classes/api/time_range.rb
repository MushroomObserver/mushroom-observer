# encoding: utf-8

class API
  # Parses and returns ranges of dates
  class TimeRange
    PARSERS = [:second_range, :minute_range, :hour_range,
               :seconds, :minutes, :hours]

    def self.parse(str)
      PARSERS.each do |parser|
        match = send(parser, str)
        return match if match
      end
      false
    rescue ArgumentError
      raise BadParameterValue.new(str, :date_range)
    end

    def self.second_range(str)
      Patterns.ordered_range(DateTime,
                             Patterns.range_matcher(str,
                                                    Patterns.second_patterns),
                             1, 3)
    end

    FIRST_TIMEUNIT = "01"
    LAST_TIMEUNIT = "59"

    def self.padded_datetime(str, suffix)
      sep = str.match(/\D/) ? ":" : ""
      DateTime.parse(str + sep + suffix.join(sep))
    end

    def self.minute_range(str)
      match = Patterns.range_matcher(str, Patterns.minute_patterns)
      return unless match
      from, to = [match[1], match[3]].sort
      OrderedRange.new(padded_datetime(from, [FIRST_TIMEUNIT]),
                       padded_datetime(to, [LAST_TIMEUNIT]))
    end

    def self.hour_range(str)
      match = Patterns.range_matcher(str, Patterns.hour_patterns)
      return unless match
      from, to = [match[1], match[3]].sort
      OrderedRange.new(padded_datetime(from, [FIRST_TIMEUNIT, FIRST_TIMEUNIT]),
                       padded_datetime(to, [LAST_TIMEUNIT, LAST_TIMEUNIT]))
    end

    def self.seconds(str)
      DateTime.parse(str) if Patterns.list_matcher(str,
                                                   Patterns.second_patterns)
    end

    def self.minutes(str)
      return unless Patterns.list_matcher(str, Patterns.minute_patterns)
      OrderedRange.new(padded_datetime(str, [FIRST_TIMEUNIT]),
                       padded_datetime(str, [LAST_TIMEUNIT]))
    end

    def self.hours(str)
      return unless Patterns.list_matcher(str, Patterns.hour_patterns)
      OrderedRange.new(padded_datetime(str, [FIRST_TIMEUNIT, FIRST_TIMEUNIT]),
                       padded_datetime(str, [LAST_TIMEUNIT, LAST_TIMEUNIT]))
    end
  end
end
