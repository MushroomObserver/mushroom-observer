# frozen_string_literal: true

class API2
  # Tried to create/rename a name over top of an existing one.
  class NameAlreadyExists < FatalError
    def initialize(str)
      super()
      args.merge!(new: str.to_s, old: str.to_s)
    end
  end
end
