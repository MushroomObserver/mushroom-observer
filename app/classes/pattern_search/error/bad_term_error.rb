# frozen_string_literal: true

class PatternSearch::BadTermError < PatternSearch::Error
  def to_s
    :pattern_search_bad_term_error.tp(type: args[:type], help: args[:help],
                                      term: args[:term].var.to_s.inspect)
  end
end
