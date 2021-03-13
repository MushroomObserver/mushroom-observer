# frozen_string_literal: true

module PatternSearch
  class Term
    # parse the date variable in pattern searches
    module Dates
      def parse_date_range
        val = parse_date_words
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
        else
          raise(BadDateRangeError.new(var: var, val: first_val))
        end
      end

      ##########################################################################

      private

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

      def parse_date_words
        val = make_sure_there_is_one_value!.dup
        val.tr!("_", " ")
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
        1 while val.to_s.sub!(/(^|-)(#{english}|#{translation})(-|$)/) do |word|
          first = word.sub!(/-$/, "")
          last  = word.sub!(/^-/, "")
          num2  = num == "N" ? word.to_i : num
          date  = Date.current - num2.send("#{unit}s")
          left  = format_date(date.send("beginning_of_#{unit}")) unless last
          right = format_date(date.send("end_of_#{unit}")) unless first
          [left, right].map(&:to_s).join("-")
        end
      end

      def format_date(date)
        date.strftime("%Y-%m-%d")
      end
    end
  end
end
