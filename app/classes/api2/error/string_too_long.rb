# frozen_string_literal: true

class API2
  # String parameter too long.
  class StringTooLong < Error
    def initialize(str, length)
      super()
      args.merge!(val: str.to_s, limit: length.inspect)
    end
  end
end
