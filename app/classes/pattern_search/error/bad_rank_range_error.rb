# frozen_string_literal: true

module PatternSearch
  class BadRankRangeError < Error
    def to_s
      :pattern_search_bad_rank_range_error.t(term: args[:var].inspect,
                                            value: args[:val].inspect)
    end
  end
end
