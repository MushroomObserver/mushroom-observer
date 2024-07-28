# frozen_string_literal: true

class API2
  # Request method not recognized.
  class BadMethod < FatalError
    def initialize(method)
      super()
      args.merge!(method: method.to_s)
    end
  end
end
