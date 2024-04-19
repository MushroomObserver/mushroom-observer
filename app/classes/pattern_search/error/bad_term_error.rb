# frozen_string_literal: true

module PatternSearch
  class BadTermError < Error
    def to_s
      param = args[:term].var.to_s
      value = args[:term].vals.join(",")
      # 2024-04-16: Add a message about us switching these three params.
      # Feel free to delete this and the translation string
      # :pattern_search_bad_term_error_suggestion, after a while.
      if %w[images sequence specimen].include?(param)
        new_term = "has_#{param}"
        gen = "#{:pattern_search_bad_term_error_suggestion.tp(
          term: param, new_term: new_term, vals: value
        )}\n"
      else
        gen = ""
      end
      gen += :pattern_search_bad_term_error.tp(
        type: args[:type], help: args[:help],
        term: param.inspect
      )
      gen
    end
  end
end
