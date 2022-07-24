# frozen_string_literal: true

module PatternSearch
  class SyntaxError < Error
    def to_s
      :pattern_search_syntax_error.t(string: args[:string].inspect)
    end
  end
end
