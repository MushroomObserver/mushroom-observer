class API
  module Parsers
    # Parse dates for API.
    class DateParser < Base
      include DateTimePatterns

      def parse(str)
        scalar_yyyymmdd(str)
      rescue ArgumentError
        raise BadParameterValue.new(str, :date)
      end

      def parse_range
        args[:range] = true
        str = clean_param
        return args[:default] unless str
        try_all_range_patterns(str)
      rescue ArgumentError
        raise BadParameterValue.new(str, :date_range)
      end

      private

      def try_all_range_patterns(str)
        range_yyyymmdd_x2(str) ||
          range_yyyymm_x2(str) ||
          range_yyyy_x2(str) ||
          range_mmdd_x2(str) ||
          range_mm_x2(str) ||
          range_yyyymmdd(str) ||
          range_yyyymm(str) ||
          range_yyyy(str) ||
          range_mmdd(str) ||
          range_mm(str) ||
          raise(ArgumentError)
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity

      def range_yyyymmdd_x2(str)
        match = str.match(/^(#{YYYYMMDD1})\s*-\s*(#{YYYYMMDD1})$/) ||
                str.match(/^(#{YYYYMMDD2})\s*-\s*(#{YYYYMMDD2})$/) ||
                str.match(/^(#{YYYYMMDD3})\s*-\s*(#{YYYYMMDD3})$/)
        return unless match
        from = strip_time(match[1])
        to   = strip_time(match[2])
        from = Date.parse(from)
        to   = Date.parse(to)
        OrderedRange.new(from, to)
      end

      def range_yyyymm_x2(str)
        match = str.match(/^(#{YYYYMM1})\s*-\s*(#{YYYYMM1})$/) ||
                str.match(/^(#{YYYYMM2})\s*-\s*(#{YYYYMM2})$/) ||
                str.match(/^(#{YYYYMM3})\s*-\s*(#{YYYYMM3})$/)
        return unless match
        from = strip_time(match[1]) + "01"
        to   = strip_time(match[2]) + "01"
        from = Date.parse(from)
        to   = Date.parse(to).next_month.prev_day
        OrderedRange.new(from, to)
      end

      def range_yyyy_x2(str)
        match = str.match(/^(#{YYYY})\s*-\s*(#{YYYY})$/)
        return unless match
        from = strip_time(match[1])
        to   = strip_time(match[2])
        return if from < "1500"
        from = Date.parse(from + "0101")
        to   = Date.parse(to + "1231")
        OrderedRange.new(from, to)
      end

      def range_mmdd_x2(str)
        match = str.match(/^#{MMDD1}\s*-\s*#{MMDD1}$/) ||
                str.match(/^#{MMDD2}\s*-\s*#{MMDD2}$/) ||
                str.match(/^#{MMDD3}\s*-\s*#{MMDD3}$/)
        return unless match
        from = match[1].to_i * 100 + match[2].to_i
        to   = match[3].to_i * 100 + match[4].to_i
        OrderedRange.new(from, to)
      end

      def range_mm_x2(str)
        match = str.match(/^#{MM}\s*-\s*#{MM}$/)
        return unless match
        from = match[1].to_i
        to   = match[2].to_i
        OrderedRange.new(from, to)
      end

      def range_yyyymmdd(str)
        match = str.match(/^#{YYYYMMDD1}$/) ||
                str.match(/^#{YYYYMMDD2}$/) ||
                str.match(/^#{YYYYMMDD3}$/)
        return unless match
        str  = strip_time(str)
        date = Date.parse(str)
        OrderedRange.new(date, date)
      end

      def range_yyyymm(str)
        match = str.match(/^#{YYYYMM1}$/) ||
                str.match(/^#{YYYYMM2}$/) ||
                str.match(/^#{YYYYMM3}$/)
        return unless match
        str  = strip_time(str)
        from = Date.parse(str + "01")
        to   = from.next_month.prev_day
        OrderedRange.new(from, to)
      end

      def range_yyyy(str)
        match = str.match(/^#{YYYY}$/)
        return unless match
        return if str < "1500"
        from = Date.parse(str + "0101")
        to   = Date.parse(str + "1231")
        OrderedRange.new(from, to)
      end

      def range_mmdd(str)
        match = str.match(/^#{MMDD1}$/) ||
                str.match(/^#{MMDD2}$/) ||
                str.match(/^#{MMDD3}$/)
        return unless match
        monthday = match[1].to_i * 100 + match[2].to_i
        OrderedRange.new(monthday, monthday)
      end

      def range_mm(str)
        match = str.match(/^#{MM}$/)
        return unless match
        month = str.to_i
        OrderedRange.new(month, month)
      end

      def scalar_yyyymmdd(str)
        match = str.match(/^#{YYYYMMDD1}$/) ||
                str.match(/^#{YYYYMMDD2}$/) ||
                str.match(/^#{YYYYMMDD3}$/)
        raise ArgumentError unless match
        str = strip_time(str)
        Date.parse(str)
      end
    end
  end
end
