module PatternSearch
  class Error < ::StandardError
    attr_accessor :args

    def initialize(args)
      self.args = args
    end
  end

  class SyntaxError < Error
    def to_s
      :pattern_search_syntax_error.t(string: args[:string].inspect)
    end
  end

  class BadTermError < Error
    def to_s
      :pattern_search_bad_term_error.tp(type: args[:type], help: args[:help],
                                        term: args[:term].var.to_s.inspect)
    end
  end

  class MissingValueError < Error
    def to_s
      :pattern_search_missing_value_error.t(var: args[:var].inspect)
    end
  end

  class TooManyValuesError < Error
    def to_s
      :pattern_search_too_many_values_error.t(term: args[:var].inspect)
    end
  end

  class BadBooleanError < Error
    def to_s
      :pattern_search_bad_boolean_error.t(term: args[:var].inspect,
                                          value: args[:val].inspect)
    end
  end

  class BadYesError < Error
    def to_s
      :pattern_search_bad_yes_error.t(term: args[:var].inspect,
                                      value: args[:val].inspect)
    end
  end

  class BadYesNoBothError < Error
    def to_s
      :pattern_search_bad_yes_no_both_error.t(term: args[:var].inspect,
                                              value: args[:val].inspect)
    end
  end

  class BadFloatError < Error
    def to_s
      :pattern_search_bad_float_error.t(term: args[:var].inspect,
                                        value: args[:val].inspect,
                                        min: args[:min].inspect,
                                        max: args[:max].inspect)
    end
  end

  class BadNameError < Error
    def to_s
      :pattern_search_bad_name_error.t(term: args[:var].inspect,
                                       value: args[:val].inspect)
    end
  end

  class BadHerbariumError < Error
    def to_s
      :pattern_search_bad_herbarium_error.t(term: args[:var].inspect,
                                            value: args[:val].inspect)
    end
  end

  class BadLocationError < Error
    def to_s
      :pattern_search_bad_location_error.t(term: args[:var].inspect,
                                           value: args[:val].inspect)
    end
  end

  class BadProjectError < Error
    def to_s
      :pattern_search_bad_project_error.t(term: args[:var].inspect,
                                          value: args[:val].inspect)
    end
  end

  class BadSpeciesListError < Error
    def to_s
      :pattern_search_bad_species_list_error.t(term: args[:var].inspect,
                                               value: args[:val].inspect)
    end
  end

  class BadUserError < Error
    def to_s
      :pattern_search_bad_user_error.t(term: args[:var].inspect,
                                       value: args[:val].inspect)
    end
  end

  class BadConfidenceError < Error
    def to_s
      :pattern_search_bad_confidence_error.t(term: args[:var].inspect,
                                             value: args[:val].inspect)
    end
  end

  class BadDateRangeError < Error
    def to_s
      :pattern_search_bad_date_range_error.t(term: args[:var].inspect,
                                             value: args[:val].inspect)
    end
  end

  class BadRankRangeError < Error
    def to_s
      :pattern_search_bad_rank_range_error.t(term: args[:var].inspect,
                                             value: args[:val].inspect)
    end
  end
end
