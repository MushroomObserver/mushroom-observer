# frozen_string_literal: true

class API2
  # Method not implemented for this endpoint.
  class NoMethodForAction < FatalError
    def initialize(method, action)
      super()
      args.merge!(method: method.to_s.upcase, action: action.to_s)
    end
  end
end
