# frozen_string_literal: true

class API2
  # APIKey not valid.
  class BadAPIKey < FatalError
    def initialize(str)
      super()
      args.merge!(key: str.to_s)
    end
  end
end
