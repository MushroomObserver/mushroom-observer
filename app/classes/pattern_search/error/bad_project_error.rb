# frozen_string_literal: true

class PatternSearch::BadProjectError < PatternSearch::Error
  def to_s
    :pattern_search_bad_project_error.t(term: args[:var].inspect,
                                        value: args[:val].inspect)
  end
end
