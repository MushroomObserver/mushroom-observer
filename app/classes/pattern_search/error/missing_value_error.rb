# frozen_string_literal: true

class PatternSearch::MissingValueError < PatternSearch::Error
  def to_s
    :pattern_search_missing_value_error.t(var: args[:var].inspect)
  end
end
