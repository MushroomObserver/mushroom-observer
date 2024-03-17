# frozen_string_literal: true

class API2
  # Cannot update location/name unless you own all its observations.
  class MustOwnAllObservations < FatalError
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end
end
