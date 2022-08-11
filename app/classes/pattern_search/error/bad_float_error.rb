# frozen_string_literal: true

module PatternSearch
  class BadFloatError < Error
    def to_s
      :pattern_search_bad_float_error.t(term: args[:var].inspect,
                                        value: args[:val].inspect,
                                        min: args[:min].inspect,
                                        max: args[:max].inspect)
    end
  end
end
