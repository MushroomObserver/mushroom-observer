# frozen_string_literal: true

class API2
  # Some PATCH set parameters, if supplied, cannot be blank.
  class ParameterCantBeBlank < FatalError
    def initialize(arg)
      super()
      args.merge!(arg: arg.to_s)
    end
  end
end
