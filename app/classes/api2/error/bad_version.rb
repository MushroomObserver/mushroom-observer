# frozen_string_literal: true

class API2
  # Syntax of requested version is wrong.
  class BadVersion < FatalError
    def initialize(str)
      super()
      args.merge!(version: str.to_s)
    end
  end
end
