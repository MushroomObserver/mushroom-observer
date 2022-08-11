# frozen_string_literal: true

class API2
  # User not verified yet.
  class UserNotVerified < Error
    def initialize(user)
      super()
      args.merge!(login: user.login)
    end
  end
end
