# frozen_string_literal: true

class PatternSearch::BadYesNoBothError < PatternSearch::Error
  def to_s
    :pattern_search_bad_yes_no_both_error.t(term: args[:var].inspect,
                                            value: args[:val].inspect)
  end
end
