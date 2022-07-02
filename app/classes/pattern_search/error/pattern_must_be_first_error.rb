# frozen_string_literal: true

module PatternSearch
  class PatternMustBeFirstError < Error
    def to_s
      :pattern_search_pattern_must_be_first_error.t(str: args[:str].inspect,
                                                    var: args[:var].inspect)
    end
  end
end
