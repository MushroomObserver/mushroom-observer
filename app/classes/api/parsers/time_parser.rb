class API
  module Parsers
    # Parse times for API.
    class TimeParser < Base
      include DateTimePatterns

      def parse_scalar
        str = clean_param
        return args[:default] if str.blank?
        scalar_yyyymmddhhmmss(str)
      rescue ArgumentError
        raise BadParameterValue.new(str, :time)
      end

      def parse_range
        args[:range] = true
        str = clean_param
        return args[:default] if str.blank?
        try_all_range_patterns(str)
      rescue ArgumentError
        raise BadParameterValue.new(str, :time_range)
      end
      def try_all_range_patterns(str)
        range_yyyymmddhhmmss_x2(str) ||
          range_yyyymmddhhmm_x2(str) ||
          range_yyyymmddhh_x2(str) ||
          range_yyyymmdd_x2(str) ||
          range_yyyymm_x2(str) ||
          range_yyyy_x2(str) ||
          range_yyyymmddhhmmss(str) ||
          range_yyyymmddhhmm(str) ||
          range_yyyymmddhh(str) ||
          range_yyyymmdd(str) ||
          range_yyyymm(str) ||
          range_yyyy(str) ||
          raise(ArgumentError)
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity

      def range_yyyymmddhhmmss_x2(s)
        match = s.match(/^(#{YYYYMMDDHHMMSS1})\s*-\s*(#{YYYYMMDDHHMMSS1})$/) ||
                s.match(/^(#{YYYYMMDDHHMMSS2})\s*-\s*(#{YYYYMMDDHHMMSS2})$/) ||
                s.match(/^(#{YYYYMMDDHHMMSS3})\s*-\s*(#{YYYYMMDDHHMMSS3})$/)
        return unless match
        from = strip_time(match[1]) + " UTC"
        to   = strip_time(match[2]) + " UTC"
        from = DateTime.parse(from)
        to   = DateTime.parse(to)
        OrderedRange.new(from, to)
      end

      def range_yyyymmddhhmm_x2(str)
        match = str.match(/^(#{YYYYMMDDHHMM1})\s*-\s*(#{YYYYMMDDHHMM1})$/) ||
                str.match(/^(#{YYYYMMDDHHMM2})\s*-\s*(#{YYYYMMDDHHMM2})$/) ||
                str.match(/^(#{YYYYMMDDHHMM3})\s*-\s*(#{YYYYMMDDHHMM3})$/)
        return unless match
        from = strip_time(match[1]) + "00 UTC"
        to   = strip_time(match[2]) + "59 UTC"
        from = DateTime.parse(from)
        to   = DateTime.parse(to)
        OrderedRange.new(from, to)
      end

      def range_yyyymmddhh_x2(str)
        match = str.match(/^(#{YYYYMMDDHH1})\s*-\s*(#{YYYYMMDDHH1})$/) ||
                str.match(/^(#{YYYYMMDDHH2})\s*-\s*(#{YYYYMMDDHH2})$/) ||
                str.match(/^(#{YYYYMMDDHH3})\s*-\s*(#{YYYYMMDDHH3})$/)
        return unless match
        from = strip_time(match[1]) + "0000 UTC"
        to   = strip_time(match[2]) + "5959 UTC"
        from = DateTime.parse(from)
        to   = DateTime.parse(to)
        OrderedRange.new(from, to)
      end

      def range_yyyymmdd_x2(str)
        match = str.match(/^(#{YYYYMMDD1})\s*-\s*(#{YYYYMMDD1})$/) ||
                str.match(/^(#{YYYYMMDD2})\s*-\s*(#{YYYYMMDD2})$/) ||
                str.match(/^(#{YYYYMMDD3})\s*-\s*(#{YYYYMMDD3})$/)
        return unless match
        from = strip_time(match[1]) + "000000 UTC"
        to   = strip_time(match[2]) + "235959 UTC"
        from = DateTime.parse(from)
        to   = DateTime.parse(to)
        OrderedRange.new(from, to)
      end

      def range_yyyymm_x2(str)
        match = str.match(/^(#{YYYYMM1})\s*-\s*(#{YYYYMM1})$/) ||
                str.match(/^(#{YYYYMM2})\s*-\s*(#{YYYYMM2})$/) ||
                str.match(/^(#{YYYYMM3})\s*-\s*(#{YYYYMM3})$/)
        return unless match
        from = strip_time(match[1])
        to   = strip_time(match[2])
        to   = Date.parse(to + "01").next_month.prev_day.to_s
        from = DateTime.parse(from + "01000000 UTC")
        to   = DateTime.parse(strip_time(to) + "235959 UTC")
        OrderedRange.new(from, to)
      end

      def range_yyyy_x2(str)
        match = str.match(/^(#{YYYY})\s*-\s*(#{YYYY})$/)
        return unless match
        from = strip_time(match[1]) + "0101000000 UTC"
        to   = strip_time(match[2]) + "1231235959 UTC"
        from = DateTime.parse(from)
        to   = DateTime.parse(to)
        OrderedRange.new(from, to)
      end

      def range_yyyymmddhhmmss(str)
        match = str.match(/^#{YYYYMMDDHHMMSS1}$/) ||
                str.match(/^#{YYYYMMDDHHMMSS2}$/) ||
                str.match(/^#{YYYYMMDDHHMMSS3}$/)
        return unless match
        str  = strip_time(str) + " UTC"
        time = DateTime.parse(str)
        OrderedRange.new(time, time)
      end

      def range_yyyymmddhhmm(str)
        match = str.match(/^#{YYYYMMDDHHMM1}$/) ||
                str.match(/^#{YYYYMMDDHHMM2}$/) ||
                str.match(/^#{YYYYMMDDHHMM3}$/)
        return unless match
        str  = strip_time(str)
        from = DateTime.parse(str + "00 UTC")
        to   = DateTime.parse(str + "59 UTC")
        OrderedRange.new(from, to)
      end

      def range_yyyymmddhh(str)
        match = str.match(/^#{YYYYMMDDHH1}$/) ||
                str.match(/^#{YYYYMMDDHH2}$/) ||
                str.match(/^#{YYYYMMDDHH3}$/)
        return unless match
        str  = strip_time(str)
        from = DateTime.parse(str + "0000 UTC")
        to   = DateTime.parse(str + "5959 UTC")
        OrderedRange.new(from, to)
      end

      def range_yyyymmdd(str)
        match = str.match(/^#{YYYYMMDD1}$/) ||
                str.match(/^#{YYYYMMDD2}$/) ||
                str.match(/^#{YYYYMMDD3}$/)
        return unless match
        str  = strip_time(str)
        from = DateTime.parse(str + "000000 UTC")
        to   = DateTime.parse(str + "235959 UTC")
        OrderedRange.new(from, to)
      end

      def range_yyyymm(str)
        match = str.match(/^#{YYYYMM1}$/) ||
                str.match(/^#{YYYYMM2}$/) ||
                str.match(/^#{YYYYMM3}$/)
        return unless match
        str  = strip_time(str) + "01"
        str2 = Date.parse(str).next_month.prev_day.to_s
        str2 = strip_time(str2)
        from = DateTime.parse(str + "000000 UTC")
        to   = DateTime.parse(str2 + "235959 UTC")
        OrderedRange.new(from, to)
      end

      def range_yyyy(str)
        match = str.match(/^#{YYYY}$/)
        return unless match
        str  = strip_time(str)
        from = DateTime.parse(str + "0101000000 UTC")
        to   = DateTime.parse(str + "1231235959 UTC")
        OrderedRange.new(from, to)
      end

      def scalar_yyyymmddhhmmss(str)
        match = str.match(/^#{YYYYMMDDHHMMSS1}$/) ||
                str.match(/^#{YYYYMMDDHHMMSS2}$/) ||
                str.match(/^#{YYYYMMDDHHMMSS3}$/)
        raise ArgumentError unless match
        str = strip_time(str) + " UTC"
        DateTime.parse(str)
      end
    end
  end
end
