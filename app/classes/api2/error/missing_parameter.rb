# frozen_string_literal: true

class API2
  # Missing required parameter.
  class MissingParameter < FatalError
    def initialize(arg)
      super()
      args.merge!(arg: arg.to_s)
    end
  end
end
