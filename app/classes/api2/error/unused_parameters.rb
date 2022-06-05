# frozen_string_literal: true

class API2
  # Request included unexpected parameters.
  class UnusedParameters < Error
    def initialize(params)
      super()
      args.merge!(params: params.map(&:to_s).sort.join(", "))
    end
  end
end