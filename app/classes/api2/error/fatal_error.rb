# frozen_string_literal: true

class API2
  # API fatal exception base class.
  class FatalError < Error
    def initialize
      super
      self.fatal = true
    end
  end
end
