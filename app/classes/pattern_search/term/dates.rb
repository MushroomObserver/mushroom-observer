# frozen_string_literal: true

module PatternSearch
  class Term
    # parse the date variable in pattern searches
    module Dates
      def parse_date_range
        val = make_sure_there_is_one_value!.dup
        val = ::DateRangeParser.new(val).range
        raise(BadDateRangeError.new(var: var, val: first_val)) if val.nil?

        val
      end
    end
  end
end
