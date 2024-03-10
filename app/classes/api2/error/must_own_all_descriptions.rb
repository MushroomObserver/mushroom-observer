# frozen_string_literal: true

class API2
  # Can only update locations/names which you own all the desrciptions for.
  class MustOwnAllDescriptions < FatalError
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end
end
