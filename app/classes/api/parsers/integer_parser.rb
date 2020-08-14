# frozen_string_literal: true

class API
  module Parsers
    # Parse integer for API.
    class IntegerParser < Base
      def parse(str)
        raise(BadParameterValue.new(str, :integer)) unless /^-?\d+$/.match?(str)

        val = str.to_i
        limit = args[:limit]
        return val if !limit || limit.include?(val)

        raise(BadLimitedParameterValue.new(str, limit))
      end

      # Reduce trivial ranges to just a single value.
      def parse_range
        val = super || return
        val.begin == val.end ? val.begin : val
      end
    end
  end
end
