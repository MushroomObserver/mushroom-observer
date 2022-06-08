# frozen_string_literal: true

class PatternSearch::TooManyValuesError < PatternSearch::Error
  def to_s
    :pattern_search_too_many_values_error.t(term: args[:var].inspect)
  end
end
