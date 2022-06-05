# frozen_string_literal: true

class API2
  # Cannot update location unless you own all its species lists.
  class MustOwnAllSpeciesLists < Error
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end
end