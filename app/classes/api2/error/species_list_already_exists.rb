# frozen_string_literal: true

class API2
  # Tried to create species list that already exists.
  class SpeciesListAlreadyExists < FatalError
    def initialize(str)
      super()
      args.merge!(title: str)
    end
  end
end
