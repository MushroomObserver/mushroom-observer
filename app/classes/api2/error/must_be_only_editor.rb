# frozen_string_literal: true

class API2
  # Cannot update locations/names which other users have edited.
  class MustBeOnlyEditor < Error
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end
end