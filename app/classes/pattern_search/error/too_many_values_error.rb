# frozen_string_literal: true

module PatternSearch
  class TooManyValuesError < Error
    def to_s
      :pattern_search_too_many_values_error.t(term: args[:var].inspect)
    end
  end
end
