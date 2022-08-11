# frozen_string_literal: true

class API2
  # Parameter value out of range.
  class BadLimitedParameterValue < Error
    def initialize(str, limit)
      super()
      args.merge!(val: str.to_s, limit: limit.inspect)
    end
  end
end
