# encoding: utf-8

class API
  # Provides common regular expressions and matches
  class Patterns
    TWO = '\d\d?'
    DAY = TWO
    MONTH = TWO
    YEAR = '\d{4}'
    SEPARATOR = '\s*-\s*'
    NUM_DATE = '\d{8}()'
    DASH_DATE = "#{YEAR}(-)#{MONTH}-#{DAY}"
    SLASH_DATE = "#{YEAR}(\\/)#{MONTH}\\/#{DAY}"
    DATE_PATTERNS = [NUM_DATE, DASH_DATE, SLASH_DATE]

    NUM_MONTH = '\d{6}()'
    DASH_MONTH = "#{YEAR}(-)#{MONTH}"
    SLASH_MONTH = "#{YEAR}(\\/)#{MONTH}"
    MONTH_PATTERNS = [NUM_MONTH, DASH_MONTH, SLASH_MONTH]

    NUM_SECONDS = '\d{14}()'
    SECONDS_TIME = "#{TWO}:#{TWO}:#{TWO}"
    DASH_SECONDS = "#{DASH_DATE} #{SECONDS_TIME}"
    SLASH_SECONDS = "#{SLASH_DATE} #{SECONDS_TIME}"
    SECOND_PATTERNS = [NUM_SECONDS, DASH_SECONDS, SLASH_SECONDS]

    NUM_MINUTES = '\d{12}()'
    MINUTES_TIME = "#{TWO}:#{TWO}"
    DASH_MINUTES = "#{DASH_DATE} #{MINUTES_TIME}"
    SLASH_MINUTES = "#{SLASH_DATE} #{MINUTES_TIME}"
    MINUTE_PATTERNS = [NUM_MINUTES, DASH_MINUTES, SLASH_MINUTES]

    NUM_HOURS = '\d{10}()'
    HOURS_TIME = "#{TWO}"
    DASH_HOURS = "#{DASH_DATE} #{HOURS_TIME}"
    SLASH_HOURS = "#{SLASH_DATE} #{HOURS_TIME}"
    HOUR_PATTERNS = [NUM_HOURS, DASH_HOURS, SLASH_HOURS]

    NUM_MONTH_DAY = "(#{MONTH})(#{DAY})"
    DASH_MONTH_DAY = "(#{MONTH})-(#{DAY})"
    SLASH_MONTH_DAY = "(#{MONTH})\\/(#{DAY})"
    MONTH_DAY_PATTERNS = [NUM_MONTH_DAY, DASH_MONTH_DAY, SLASH_MONTH_DAY]

    def self.single_pattern(pattern)
      "^(#{pattern})$"
    end

    def self.list_matcher(str, patterns)
      patterns.each do |pat|
        match = str.match(Regexp.new(single_pattern(pat)))
        return match if match
      end
      false
    end

    def self.range_pattern(pattern)
      "^(#{pattern})#{SEPARATOR}(#{pattern})$"
    end

    def self.range_matcher(str, patterns)
      patterns.each do |pat|
        match = str.match(Regexp.new(range_pattern(pat)))
        return match if match
      end
      false
    end

    def self.date(str)
      list_matcher(str, DATE_PATTERNS)
    end

    def self.date_range(str)
      range_matcher(str, DATE_PATTERNS)
    end

    def self.month(str)
      list_matcher(str, MONTH_PATTERNS)
    end

    def self.month_range(str)
      range_matcher(str, MONTH_PATTERNS)
    end

    def self.seconds(str)
      list_matcher(str, SECOND_PATTERNS)
    end

    def self.second_range(str)
      range_matcher(str, SECOND_PATTERNS)
    end

    def self.minutes(str)
      list_matcher(str, MINUTE_PATTERNS)
    end

    def self.minute_range(str)
      range_matcher(str, MINUTE_PATTERNS)
    end

    def self.hours(str)
      list_matcher(str, HOUR_PATTERNS)
    end

    def self.hour_range(str)
      range_matcher(str, HOUR_PATTERNS)
    end

    def self.year(str)
      list_matcher(str, [YEAR])
    end

    def self.year_range(str)
      range_matcher(str, [YEAR])
    end

    def self.just_month(str)
      list_matcher(str, [MONTH])
    end

    def self.just_month_range(str)
      range_matcher(str, [MONTH])
    end

    def self.month_day(str)
      list_matcher(str, MONTH_DAY_PATTERNS)
    end

    def self.month_day_range(str)
      range_matcher(str, MONTH_DAY_PATTERNS)
    end
  end
end
