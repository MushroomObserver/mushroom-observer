# frozen_string_literal: true

class API2
  # Error rendering API request results.
  class RenderFailed < FatalError
    def initialize(error)
      super()
      msg = "#{error}\n#{error.backtrace.join("\n")}"
      args.merge!(error: msg)
    end
  end
end
