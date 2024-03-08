# frozen_string_literal: true

class API2
  # Can only update locations/names which you have created.
  class MustBeCreator < FatalError
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end
end
