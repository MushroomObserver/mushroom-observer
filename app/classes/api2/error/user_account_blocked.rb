# frozen_string_literal: true

class API2
  # Account has been disabled/blocked (e.g. self-deleted); its API keys
  # are retained but must not authenticate.
  class UserAccountBlocked < FatalError
    def initialize(user)
      super()
      args.merge!(login: user.login)
    end
  end
end
