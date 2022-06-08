# frozen_string_literal: true

class PatternSearch::PatternMustBeFirstError < PatternSearch::Error
  def to_s
    :pattern_search_pattern_must_be_first_error.t(str: args[:str].inspect,
                                                  var: args[:var].inspect)
  end
end
