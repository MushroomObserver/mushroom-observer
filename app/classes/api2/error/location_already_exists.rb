# frozen_string_literal: true

class API2
  # Tried to create/rename a location over top of an existing one.
  class LocationAlreadyExists < Error
    def initialize(str)
      super()
      args.merge!(location: str.to_s)
    end
  end
end