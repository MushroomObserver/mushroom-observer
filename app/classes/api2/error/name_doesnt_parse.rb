# frozen_string_literal: true

class API2
  # Taxon name isn't valid.
  class NameDoesntParse < Error
    def initialize(str)
      super()
      args.merge!(name: str.to_s)
    end
  end
end
