# frozen_string_literal: true

module PatternSearch
  class BadLocationError < Error
    def to_s
      :pattern_search_bad_location_error.t(term: args[:var].inspect,
                                           value: args[:val].inspect)
    end
  end
end
