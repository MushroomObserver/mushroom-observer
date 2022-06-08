# frozen_string_literal: true

class PatternSearch::SyntaxError < PatternSearch::Error
  def to_s
    :pattern_search_syntax_error.t(string: args[:string].inspect)
  end
end
