# frozen_string_literal: true

module PatternSearch
  class UserMeNotLoggedInError < Error
    def to_s
      :pattern_search_user_me_not_logged_in_error.t
    end
  end
end
