# frozen_string_literal: true

class API2
  # Can only update names which no one else has proposed on any observations.
  class MustOwnAllNamings < FatalError
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end
end
