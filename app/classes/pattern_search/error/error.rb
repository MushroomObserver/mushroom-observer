# frozen_string_literal: true

module PatternSearch
  class Error < ::StandardError
    attr_accessor :args

    def initialize(args = {})
      super
      self.args = args
    end
  end
end
