# frozen_string_literal: true

class API2
  # Notes template field didn't parse.
  class BadNotesFieldParameter < FatalError
    def initialize(str)
      super()
      args.merge!(val: str.to_s)
    end
  end
end
