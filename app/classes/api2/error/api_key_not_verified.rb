# frozen_string_literal: true

class API2
  # APIKey not verified yet.
  class APIKeyNotVerified < FatalError
    def initialize(key)
      super()
      args.merge!(key: key.key.to_s, notes: key.notes.to_s)
    end
  end
end
