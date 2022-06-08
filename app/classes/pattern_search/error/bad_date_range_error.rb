# frozen_string_literal: true

module PatternSearch
  class BadDateRangeError < Error
    def to_s
      :pattern_search_bad_date_range_error.t(term: args[:var].inspect,
                                            value: args[:val].inspect)
    end
  end
end
