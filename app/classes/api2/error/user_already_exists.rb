# frozen_string_literal: true

class API2
  # Tried to create user that already exists.
  class UserAlreadyExists < FatalError
    def initialize(str)
      super()
      args.merge!(login: str)
    end
  end
end
