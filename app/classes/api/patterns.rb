# encoding: utf-8

class API
  # Provides common regular expressions and matches
  class Patterns
    TWO = '\d\d?'
    DAY = TWO
    MONTH = TWO
    def self.month_pattern
      MONTH
    end
    YEAR = '\d{4}'
    def self.year_pattern
      YEAR
    end
    SEPARATOR = '\s*-\s*'
    HOURS_TIME = "#{TWO}"
    MINUTES_TIME = "#{TWO}:#{TWO}"
    SECONDS_TIME = "#{TWO}:#{TWO}:#{TWO}"

    def self.month_patterns
      ['\d{6}()', "#{YEAR}(-)#{MONTH}", "#{YEAR}(\\/)#{MONTH}"]
    end

    DASH_DATE = "#{YEAR}(-)#{MONTH}-#{DAY}"
    SLASH_DATE = "#{YEAR}(\\/)#{MONTH}\\/#{DAY}"
    def self.date_patterns
      ['\d{8}()', DASH_DATE, SLASH_DATE]
    end

    def self.hour_patterns
      ['\d{10}()', "#{DASH_DATE} #{HOURS_TIME}", "#{SLASH_DATE} #{HOURS_TIME}"]
    end

    def self.minute_patterns
      ['\d{12}()',
       "#{DASH_DATE} #{MINUTES_TIME}",
       "#{SLASH_DATE} #{MINUTES_TIME}"]
    end

    def self.second_patterns
      ['\d{14}()',
       "#{DASH_DATE} #{SECONDS_TIME}",
       "#{SLASH_DATE} #{SECONDS_TIME}"]
    end

    def self.month_day_patterns
      ["(#{MONTH})(#{DAY})", "(#{MONTH})-(#{DAY})", "(#{MONTH})\\/(#{DAY})"]
    end

    def self.matcher(str, patterns, pattern_finalizer)
      patterns.each do |pat|
        match = str.match(Regexp.new(send(pattern_finalizer, pat)))
        return match if match
      end
      false
    end

    def self.list_matcher(str, patterns)
      matcher(str, patterns, :single_pattern)
    end

    def self.single_pattern(pattern)
      "^(#{pattern})$"
    end

    def self.range_matcher(str, patterns)
      matcher(str, patterns, :range_pattern)
    end

    def self.range_pattern(pattern)
      "^(#{pattern})#{SEPARATOR}(#{pattern})$"
    end

    def self.ordered_range(cls, match, from_index, to_index)
      return unless match
      OrderedRange.new(cls.parse(match[from_index]),
                       cls.parse(match[to_index]))
    end
  end
end
