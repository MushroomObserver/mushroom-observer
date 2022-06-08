# frozen_string_literal: true

class PatternSearch::BadHerbariumError < PatternSearch::Error
  def to_s
    :pattern_search_bad_herbarium_error.t(term: args[:var].inspect,
                                          value: args[:val].inspect)
  end
end
