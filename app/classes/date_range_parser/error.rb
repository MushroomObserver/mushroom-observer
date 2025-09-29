# frozen_string_literal: true

module DateRangeParser
  class Error < ::StandardError
    attr_accessor :args

    def initialize(args = {})
      super
      self.args = args
    end

    def to_s
      :date_range_parser_error.t(value: args[:val].inspect)
    end
  end
end
