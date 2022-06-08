# frozen_string_literal: true

module PatternSearch
  class BadUserError < Error
    def to_s
      :pattern_search_bad_user_error.t(term: args[:var].inspect,
                                      value: args[:val].inspect)
    end
  end
end
