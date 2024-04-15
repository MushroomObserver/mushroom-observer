# frozen_string_literal: true

module PatternSearch
  class BadTermError < Error
    def to_s
      param = args[:term].var.to_s
      value = args[:term].vals.join(",")
      # Add a message about switching params if there is a "has_" param.
      if param.include?("has_")
        new_term = param.sub("has_", "with_")
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
