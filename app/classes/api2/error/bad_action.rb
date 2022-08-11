# frozen_string_literal: true

class API2
  # Endpoint doesn't exist.
  class BadAction < Error
    def initialize(action)
      super()
      args.merge!(action: action.to_s)
    end
  end
end
