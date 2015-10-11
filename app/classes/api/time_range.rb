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
      match = Patterns.second_range(str)
      return unless match
      OrderedRange.new(DateTime.parse(match[1]),
                       DateTime.parse(match[3]))
    end

    FIRST_TIMEUNIT = "01"
    LAST_TIMEUNIT = "59"

    def self.padded_datetime(str, suffix)
      sep = str.match(/\D/) ? ":" : ""
      DateTime.parse(str + sep + suffix.join(sep))
    end

    def self.minute_range(str)
      match = Patterns.minute_range(str)
      return unless match
      from, to = [match[1], match[3]].sort
      OrderedRange.new(padded_datetime(from, [FIRST_TIMEUNIT]),
                       padded_datetime(to, [LAST_TIMEUNIT]))
    end

    def self.hour_range(str)
      match = Patterns.hour_range(str)
      return unless match
      from, to = [match[1], match[3]].sort
      OrderedRange.new(padded_datetime(from, [FIRST_TIMEUNIT, FIRST_TIMEUNIT]),
                       padded_datetime(to, [LAST_TIMEUNIT, LAST_TIMEUNIT]))
    end

    def self.seconds(str)
      DateTime.parse(str) if Patterns.seconds(str)
    end

    def self.minutes(str)
      return unless Patterns.minutes(str)
      OrderedRange.new(padded_datetime(str, [FIRST_TIMEUNIT]),
                       padded_datetime(str, [LAST_TIMEUNIT]))
    end

    def self.hours(str)
      return unless Patterns.hours(str)
      OrderedRange.new(padded_datetime(str, [FIRST_TIMEUNIT, FIRST_TIMEUNIT]),
                       padded_datetime(str, [LAST_TIMEUNIT, LAST_TIMEUNIT]))
    end
  end
end
