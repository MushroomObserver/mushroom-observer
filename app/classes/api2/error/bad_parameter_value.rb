# frozen_string_literal: true

class API2
  # Parameter has bad syntax.
  class BadParameterValue < FatalError
    def initialize(str, type)
      super()
      args.merge!(val: str.to_s, type: type)
      self.tag = :"api_bad_#{type}_parameter_value"
    end
  end
end
